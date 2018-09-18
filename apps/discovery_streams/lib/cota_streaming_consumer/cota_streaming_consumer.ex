require Logger
require Poison
require GenServer
alias StreamingMetrics.Hostname

defmodule CotaStreamingConsumer do
  @cache Application.get_env(:cota_streaming_consumer, :cache)
  @metric_collector Application.get_env(:streaming_metrics, :collector)

  def handle_messages(messages) do

    json_messages =
      messages
      |> Enum.map(fn message -> message.value end)
      |> Enum.map(&log_message/1)
      |> Enum.map(&Poison.Parser.parse!/1)

    record_outbound_count_metrics(json_messages)

    Enum.each(json_messages, &add_to_cache/1)
    Enum.each(json_messages, &broadcast/1)
  end

  defp record_outbound_count_metrics(messages) do
    hostname = get_hostname()

    messages
    |> Enum.count()
    |> @metric_collector.count_metric("Outbound Records", [{"PodHostname", "#{hostname}"}])
    |> List.wrap()
    |> @metric_collector.record_metrics("COTA Streaming")
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("Unable to write application metrics: #{inspect(reason)}")
    end
  end

  defp add_to_cache(message) do
    GenServer.abcast(
      CotaStreamingConsumer.CacheGenserver,
      {:put, message["vehicle"]["vehicle"]["id"], message}
    )
  end

  defp broadcast(data) do
    CotaStreamingConsumerWeb.Endpoint.broadcast!("vehicle_position", "update", data)
  end

  defp log_message(value) do
    Logger.log(:debug, value)
    value
  end

  defp get_hostname(), do: Hostname.get()
end
