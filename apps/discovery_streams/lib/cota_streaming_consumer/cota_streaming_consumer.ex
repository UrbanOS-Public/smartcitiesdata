require Logger
require Poison

defmodule CotaStreamingConsumer do
  @cache Application.get_env(:cota_streaming_consumer, :cache)

  def handle_messages(messages) do
    json_messages =
      messages
      |> Enum.map(fn message -> message.value end)
      |> Enum.map(&log_message/1)
      |> Enum.map(&Poison.Parser.parse!/1)

    Enum.each(json_messages, &add_to_cache/1)
    Enum.each(json_messages, &broadcast/1)

    :ok
  end

  defp add_to_cache(message) do
    Cachex.put(@cache, message["vehicle"]["vehicle"]["id"], message)
  end

  defp broadcast(data) do
    CotaStreamingConsumerWeb.Endpoint.broadcast!("vehicle_position", "update", data)
  end

  defp log_message(value) do
    Logger.log(:debug, value)
    value
  end
end
