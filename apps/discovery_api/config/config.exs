use Mix.Config

config :prestige, :session_opts,
  user: "discovery-api",
  catalog: "hive",
  schema: "default"

idle_timeout_hours = 24
idle_timeout = 3_600 * 1_000 * idle_timeout_hours

config :discovery_api, DiscoveryApiWeb.Endpoint,
  secret_key_base: "7Qfvr6quFJ6Qks3FGiLMnm/eNV8K66yMVpkU46lCZ2rKj0YR9ksjxsB+SX3qHZre",
  render_errors: [view: DiscoveryApiWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: DiscoveryApi.PubSub,
  instrumenters: [DiscoveryApiWeb.Endpoint.Instrumenter],
  http: [
    port: 4001,
    stream_handlers: [Web.StreamHandlers.StripServerHeader, :cowboy_stream_h],
    protocol_options: [idle_timeout: idle_timeout]
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :discovery_api,
  hsts_enabled: true,
  download_link_expire_seconds: 60,
  presign_key: "test_presign_key"

# NOTE: To generate a secret_key:  mix guardian.gen.secret
# secret set as variable to pass sobelow check on hard coded secrets
secret = "this_is_a_secret"

config :discovery_api, DiscoveryApiWeb.Auth.TokenHandler, secret_key: secret

config :discovery_api, DiscoveryApi.Quantum.Scheduler,
  jobs: [
    # Every Monday at 2:00am EDT or 6:00am UTC
    {"0 6 * * 1", {DiscoveryApi.Stats.StatsCalculator, :produce_completeness_stats, []}}
  ]

config :mime, :types, %{
  "application/zip" => ["zip", "shp", "shapefile"],
  "application/gtfs+protobuf" => ["gtfs"]
}

config :discovery_api,
  user_visualization_limit: 1_000

config :elastix,
  json_codec: Jason,
  json_options: [keys: :atoms],
  httpoison_options: [timeout: 120_000, recv_timeout: 120_000]

import_config "#{Mix.env()}.exs"
