use Mix.Config

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  debug_errors: true,
  check_origin: false,
  watchers: []

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092, kafka: 9093],
    topics: [],
    consumer_group: "discovery-streams",
    message_handler: DiscoveryStreams.MessageHandler,
    offset_reset_policy: :reset_to_latest
  ],
  producer: [
    endpoints: [localhost: 9092, kafka: 9093],
    topics: ["test"]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
