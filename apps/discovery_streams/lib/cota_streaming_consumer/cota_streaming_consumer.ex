require Logger
require Poison

defmodule CotaStreamingConsumer do
  def handle_messages(messages) do
    messages
    |> Enum.map(fn message -> message.value end)
    |> Enum.map(&log_message/1)
    |> Enum.map(&Poison.Parser.parse!/1)
    |> Enum.each(&broadcast/1)

    :ok
  end

  defp broadcast(data) do
    CotaStreamingConsumerWeb.Endpoint.broadcast!("vehicle_position", "update", data)
  end

  defp log_message(value) do
    Logger.log(:debug, value)
    value
  end
end
