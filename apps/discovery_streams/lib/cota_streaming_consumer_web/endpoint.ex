defmodule CotaStreamingConsumerWeb.Endpoint.Instrumenter do
  use Prometheus.PhoenixInstrumenter
end

defmodule CotaStreamingConsumerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :cota_streaming_consumer

  socket("/socket", CotaStreamingConsumerWeb.UserSocket)

  plug(Plug.Logger)
  plug(CotaStreamingConsumer.MetricsExporter)

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

  plug(CotaStreamingConsumerWeb.Router)

  def init(_key, config) do
    {:ok, config}
  end
end
