use Mix.Config

config :prestige,
  headers: [
    user: "discovery-api",
    catalog: "hive",
    schema: "default"
  ],
  log_level: :info

config :discovery_api, DiscoveryApiWeb.Endpoint,
  secret_key_base: "7Qfvr6quFJ6Qks3FGiLMnm/eNV8K66yMVpkU46lCZ2rKj0YR9ksjxsB+SX3qHZre",
  render_errors: [view: DiscoveryApiWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: DiscoveryApi.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [DiscoveryApiWeb.Endpoint.Instrumenter],
  http: [port: 4000]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :discovery_api,
  collector: StreamingMetrics.PrometheusMetricCollector

import_config "#{Mix.env()}.exs"
