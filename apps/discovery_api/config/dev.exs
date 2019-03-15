use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :discovery_api, DiscoveryApiWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :prestige,
  base_url: "https://presto.dev.internal.smartcolumbusos.com",
  headers: [
    user: "presto",
    catalog: "hive",
    schema: "default"
  ],
  log_level: :debug

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :mix_test_watch,
  clear: true

config :redix,
  host: "localhost"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: ["dataset-registry"],
    consumer_group: "discovery-dataset-consumer",
    message_handler: DiscoveryApi.Data.DatasetEventListener,
    rebalance_delay_ms: 10_000,
    start_with_earliest_message: true
  ]
