use Mix.Config

config :prestige, :session_opts,
  user: "discovery-api",
  catalog: "hive",
  schema: "default"

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

config :paddle, Paddle, host: "localhost", account_subdn: "ou=People"

# NOTE: To generate a secret_key:  mix guardian.gen.secret
# secret set as variable to pass sobelow check on hard coded secrets
secret = "this_is_a_secret"

config :discovery_api, DiscoveryApi.Auth.Guardian,
  issuer: "discovery_api",
  secret_key: secret

config :discovery_api, DiscoveryApi.Auth.Auth0.Guardian,
  allowed_algos: ["RS256"],
  verify_issuer: true,
  secret_fetcher: DiscoveryApi.Auth.Auth0.SecretFetcher

config :discovery_api, DiscoveryApi.Quantum.Scheduler,
  jobs: [
    # Every Monday at 2:00am EDT or 6:00am UTC
    {"0 6 * * 1", {DiscoveryApi.Stats.StatsCalculator, :produce_completeness_stats, []}}
  ]

config :mime, :types, %{
  "application/zip" => ["zip", "shp", "shapefile"]
}

import_config "#{Mix.env()}.exs"
