# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :prestige, base_url: "http://kdp-kubernetes-data-platform-presto.kdp:8080"

# Configures the endpoint
config :discovery_api, DiscoveryApiWeb.Endpoint,
  secret_key_base: "7Qfvr6quFJ6Qks3FGiLMnm/eNV8K66yMVpkU46lCZ2rKj0YR9ksjxsB+SX3qHZre",
  render_errors: [view: DiscoveryApiWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: DiscoveryApi.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [DiscoveryApiWeb.Endpoint.Instrumenter]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :discovery_api,
  data_lake_url: "https://kylo.staging.internal.smartcolumbusos.com/proxy",
  data_lake_auth_string: "c2EtZGlzY292ZXJ5LWFwaTp2WEs0aU9wRmNnNlR1T1ZXT1RCcDNRQ1BURm56UHRLQ1A5V1B3M3ds",
  cache_refresh_interval: "600000000",
  cache: :dataset_cache,
  thrive_address: "datalake-hive.staging.internal.smartcolumbusos.com",
  thrive_port: 10_000,
  thrive_username: "hive",
  thrive_password: "nopassword",
  collector: StreamingMetrics.PrometheusMetricCollector

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
