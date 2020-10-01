defmodule Valkyrie.Stream.SourceHandler do
  @moduledoc """
  Callbacks for handling data messages.
  See [Source.Handler](../../../../protocol_source/lib/source/handler.ex)
  for more.
  """
  use Source.Handler
  use Properties, otp_app: :valkyrie
  require Logger

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_standardization_end: 0]

  alias StreamingMetrics.Hostname
  alias SmartCity.Data
  alias Valkyrie.Standardization

  getter(:dlq, default: Dlq)

  def handle_message(end_of_data() = message, context) do
    Brook.Event.send(:valkyrie, data_standardization_end(), __MODULE__, %{"dataset_id" => context.dataset_id})

    Ok.ok(message)
  end

  def handle_message(message, context) do
    start_time = Data.Timing.current_time()
    schema = context.assigns.schema

    with {:ok, smart_city_data} <- SmartCity.Data.new(message),
         {:ok, standardized_payload} <- Standardization.standardize_data(schema, smart_city_data.payload) do
      smart_city_data = %{smart_city_data | payload: standardized_payload}
      |> add_timing(start_time)

      Ok.ok(smart_city_data)
    else
      {:error, reason} -> Ok.error(reason)
    end
  end

  def handle_batch(batch, context) do
    record_outbound_count_metrics(batch, context.dataset_id)
    :ok
  end

  def send_to_dlq(_dead_letters, _context) do
    # dl = DeadLetter.new(dataset_id: context.dataset_id, original_message: message, app_name: :valkyrie, reason: reason)
    # dlq().write([dl])
    :ok
  end

  defp add_timing(smart_city_data, start_time) do
    case Application.get_env(:valkyrie, :profiling_enabled) do
      true -> Data.add_timing(smart_city_data, create_timing(start_time))
      _ -> smart_city_data
    end
  end

  defp create_timing(start_time) do
    Data.Timing.new("valkyrie", "timing", start_time, Data.Timing.current_time())
  end

  defp record_outbound_count_metrics(messages, dataset_id) do
    messages
    |> Enum.reduce(%{}, fn _, acc -> Map.update(acc, dataset_id, 1, &(&1 + 1)) end)
    |> Enum.each(&record_metric/1)
  end

  defp record_metric({dataset_id, count}) do
    get_hostname()
    |> add_records(dataset_id, "outbound", count)
    |> case do
      :ok -> {}
      error -> Logger.warn("Unable to write application metrics: #{inspect(error)}")
    end
  end

  defp get_hostname(), do: Hostname.get()

  defp add_records(pod_host_name, dataset_id, type, count) do
    [
      app: "valkyrie",
      dataset_id: dataset_id,
      PodHostname: pod_host_name,
      type: type
    ]
    |> TelemetryEvent.add_event_metrics([:records], value: %{count: count})
  end
end
