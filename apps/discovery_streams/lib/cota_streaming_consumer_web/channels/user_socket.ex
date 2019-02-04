defmodule CotaStreamingConsumerWeb.UserSocket do
  use Phoenix.Socket

  channel("vehicle_position", CotaStreamingConsumerWeb.StreamingChannel)
  channel("streaming:*", CotaStreamingConsumerWeb.StreamingChannel)

  transport(:websocket, Phoenix.Transports.WebSocket)

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
