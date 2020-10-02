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
    Logger.debug(fn -> "Processing #{message} for #{context.dataset_id}" end)
    Brook.Event.send(:valkyrie, data_standardization_end(), __MODULE__, %{"dataset_id" => context.dataset_id})

    Ok.ok(message)
  end

  def handle_message(message, context) do
    schema = context.assigns.schema
    payload = message["payload"]

    case Standardization.standardize_data(schema, payload) do
      {:ok, new_payload} -> Ok.ok(Map.put(message, "payload", new_payload))
      {:error, reason} -> Ok.error(reason)
    end
  end

  def handle_batch(batch, context) do
    output_topic = context.assigns.destination
    destination_pid = context.assigns.destination_pid

    Logger.debug(fn -> "Successfully processed #{length(batch)} messages for #{inspect(context)}, sending to #{inspect(output_topic)}" end)

    Destination.write(output_topic, destination_pid, batch)

    record_outbound_count_metrics(batch, context.dataset_id)

    :ok
  end

  def send_to_dlq(dead_letters, _context) do
    Logger.debug(fn -> "Sending #{length(dead_letters)} messages to the DLQ" end)
    dlq().write(dead_letters)
    :ok
  end

  defp add_timing(smart_city_data, start_time, true = _enabled) do
    Data.add_timing(smart_city_data, create_timing(start_time))
  end
  defp add_timing(smart_city_data, _start_time, _), do: smart_city_data

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
