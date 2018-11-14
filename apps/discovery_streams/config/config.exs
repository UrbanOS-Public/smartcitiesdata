use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  http: [port: 4000],
  secret_key_base: "This is a test key",
  render_errors: [view: CotaStreamingConsumerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: CotaStreamingConsumer.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [CotaStreamingConsumerWeb.Endpoint.Instrumenter]

config :logger,
  backends: [:console],
  level: :debug,
  compile_time_purge_level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :cota_streaming_consumer, cache: :cota_vehicle_cache, ttl: 600_000

config :ex_aws,
  region: "us-east-2"

config :streaming_metrics,
  collector: StreamingMetrics.ConsoleMetricCollector

import_config "#{Mix.env()}.exs"
