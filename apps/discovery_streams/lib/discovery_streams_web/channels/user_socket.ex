defmodule DiscoveryStreamsWeb.UserSocket do
  use Phoenix.Socket

  channel("vehicle_position", DiscoveryStreamsWeb.StreamingChannel)
  channel("streaming:*", DiscoveryStreamsWeb.StreamingChannel)

  transport(:websocket, Phoenix.Transports.WebSocket)

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
