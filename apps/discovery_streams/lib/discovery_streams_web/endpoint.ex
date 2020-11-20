defmodule DiscoveryStreamsWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :discovery_streams

  socket("/socket", DiscoveryStreamsWeb.UserSocket, websocket: [transport: Phoenix.Transports.WebSocket])

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(
    Plug.Session,
    store: :cookie,
    key: "_cota_streaming_consumer_key",
    signing_salt: "qigJncyv"
  )

  plug(DiscoveryStreamsWeb.Router)

  def init(_key, config) do
    {:ok, config}
  end
end
