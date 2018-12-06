use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  server: true,
  root: ".",
  version: Application.spec(:cota_streaming_consumer, :vsn),
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint, check_origin: false

config :logger,
  level: :info

config :streaming_metrics,
  collector: StreamingMetrics.PrometheusMetricCollector

config :ex_aws,
  debug_requests: false
