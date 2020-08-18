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

  def handle_message(message, context) do
    dataset_id = context.dataset_id

    Logger.debug(fn -> "#{__MODULE__} handle_message - #{inspect(context)} - #{inspect(message)}" end)

    log_message(message)

    case Brook.get(:discovery_streams, :streaming_datasets_by_id, dataset_id) do
      {:ok, system_name} ->
        Endpoint.broadcast!("streaming:#{system_name}", "update", message)

      _ ->
        nil
    end

    Ok.ok(message)
  end

  def handle_batch(batch, context) do
    Logger.debug(fn -> "#{__MODULE__} handle_batch - #{inspect(context)} - #{inspect(batch)}" end)
    record_outbound_count_metrics(batch, context.dataset_id)
    :ok
  end

  defp log_message(message) do
    Logger.log(:info, "#{inspect(message)}")
    message
  end

  def send_to_dlq(dead_letters, _context) do
    dlq().write(dead_letters)
    :ok
  end

  defp record_outbound_count_metrics(messages, dataset_id) do
    messages
    |> Enum.reduce(%{}, fn _, acc -> Map.update(acc, dataset_id, 1, &(&1 + 1)) end)
    |> Enum.each(&record_metric/1)
  end

  defp record_metric({dataset_id, count}) do
    pretty_dataset_id =
      dataset_id
      |> String.replace("-", "_")

    get_hostname()
    |> add_records(pretty_dataset_id, "outbound", count)
    |> case do
      :ok -> {}
      error -> Logger.warn("Unable to write application metrics: #{inspect(error)}")
    end
  end

  defp get_hostname(), do: Hostname.get()

  defp add_records(pod_host_name, topic_name, type, count) do
    [
      app: "discovery_stream",
      topic_name: topic_name,
      PodHostname: pod_host_name,
      type: type
    ]
    |> TelemetryEvent.add_event_metrics([:records], value: %{count: count})
  end
end
