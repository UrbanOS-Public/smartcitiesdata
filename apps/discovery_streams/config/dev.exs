import Config

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  debug_errors: true,
  check_origin: false,
  watchers: []

config :discovery_streams, endpoints: [localhost: 9092, kafka: 9093]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
