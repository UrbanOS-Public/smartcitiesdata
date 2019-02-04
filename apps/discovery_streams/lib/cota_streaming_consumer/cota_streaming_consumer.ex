require Logger
require Poison
require GenServer
alias StreamingMetrics.Hostname

defmodule CotaStreamingConsumer do
  @moduledoc """
    Gets messages out of kafka, adds them to the cache,
    broadcasts them, and records metrics.
  """
  @metric_collector Application.get_env(:streaming_metrics, :collector)

  def handle_messages(messages) do
    json_messages =
      messages
      |> Enum.map(&log_message/1)
      |> Enum.map(&parse_message/1)

    record_outbound_count_metrics(json_messages)

    Enum.each(json_messages, &add_to_cache/1)
    Enum.each(json_messages, &broadcast/1)
  end

  defp record_outbound_count_metrics(messages) do
    messages
    |> Enum.reduce(%{}, fn %{topic: topic}, acc -> Map.update(acc, topic, 1, &(&1 + 1)) end)
    |> Enum.each(&record_metric/1)
  end

  defp record_metric({topic, count}) do
    converted_topic =
      topic
      |> String.replace("-", "_")

    count
    |> @metric_collector.count_metric("records", [{"PodHostname", "#{get_hostname()}"}, {"type", "outbound"}])
    |> List.wrap()
    |> @metric_collector.record_metrics(converted_topic)
    |> case do
      {:ok, _} -> {}
      {:error, reason} -> Logger.warn("Unable to write application metrics: #{inspect(reason)}")
    end
  end

  defp parse_message(%{value: value} = message) do
    with {:ok, parsed} <- Poison.decode(value) do
      %{message | value: parsed}
    else
      {:error, reason} -> raise ParseError, reason
    end
  end

  defp add_to_cache(%{key: key, topic: topic, value: message}) do
    GenServer.abcast(
      CotaStreamingConsumer.CacheGenserver,
      {:put, String.to_atom(topic), key, message}
    )
  end

  defp broadcast(%{topic: "cota-vehicle-positions", value: data}) do
    CotaStreamingConsumerWeb.Endpoint.broadcast("vehicle_position", "update", data)
  end

  defp broadcast(%{topic: channel, value: data}) do
    CotaStreamingConsumerWeb.Endpoint.broadcast!("streaming:#{channel}", "update", data)
  end

  defp log_message(%{value: value} = message) do
    Logger.log(:info, "#{inspect message}")
    message
  end

  defp get_hostname(), do: Hostname.get()
end
