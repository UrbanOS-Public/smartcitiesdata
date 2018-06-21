require Logger
require Poison

defmodule CotaStreamingConsumer do
  @cache Application.get_env(:cota_streaming_consumer, :cache)
  @ttl Application.get_env(:cota_streaming_consumer, :ttl)

  def handle_messages(messages) do
    json_messages =
      messages
      |> Enum.map(fn message -> message.value end)
      |> Enum.map(&log_message/1)
      |> Enum.map(&Poison.Parser.parse!/1)

    json_messages
    |> Enum.map(&add_to_cache/1)
    |> Enum.each(&broadcast/1)

    :ok
  end

  defp add_to_cache(message) do
    Cachex.put(@cache, message["vehicle"]["vehicle"]["id"], message, ttl: @ttl)
    message
  end

  defp broadcast(data) do
    CotaStreamingConsumerWeb.Endpoint.broadcast!("vehicle_position", "update", data)
  end

  defp log_message(value) do
    Logger.log(:debug, value)
    value
  end
end
