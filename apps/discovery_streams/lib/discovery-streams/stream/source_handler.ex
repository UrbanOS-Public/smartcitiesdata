defmodule DiscoveryStreams.Stream.SourceHandler do
  @moduledoc """
  Callbacks for handling data messages.
  See [Source.Handler](../../../../protocol_source/lib/source/handler.ex)
  for more.
  """
  use Source.Handler
  use Properties, otp_app: :discovery_streams
  require Logger
  alias StreamingMetrics.Hostname

  alias DiscoveryStreamsWeb.Endpoint

  getter(:dlq, default: Dlq)
  getter(:telemetry_event, default: TelemetryEvent)

  def handle_message(message, context) do
    system_name = context.assigns.system_name
    payload = get_payload(message)

    Endpoint.broadcast!("streaming:#{system_name}", "update", payload)

    Ok.ok(message)
  end

  def handle_batch(batch, context) do
    Logger.debug(fn -> "#{__MODULE__} handle_batch - #{inspect(context)} - #{inspect(batch)}" end)
    record_outbound_count_metrics(batch, context.dataset_id)
    :ok
  end

  def send_to_dlq(_dead_letters, _context) do
    # Just throw these on the ground for now.
    # dlq().write(dead_letters)
    :ok
  end

  defp get_payload(message) do
    message["payload"]
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
      app: "discovery_stream",
      dataset_id: dataset_id,
      PodHostname: pod_host_name,
      type: type
    ]
    |> telemetry_event().add_event_metrics([:records], value: %{count: count})
  end
end