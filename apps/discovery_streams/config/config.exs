use Mix.Config

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  http: [port: 4001, stream_handlers: [Web.StreamHandlers.StripServerHeader, :cowboy_stream_h]],
  secret_key_base: "This is a test key",
  render_errors: [view: DiscoveryStreamsWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: DiscoveryStreams.PubSub

config :logger,
  backends: [:console],
  level: :debug,
  compile_time_purge_matching: [[lower_level_than: :info]],
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :discovery_streams,
  ttl: 600_000,
  topic_prefix: "validated-",
  topic_subscriber_config: [
    begin_offset: :latest,
    offset_reset_policy: :reset_to_latest,
    max_bytes: 10_000_000,
    min_bytes: 0,
    max_wait_time: 10_000,
    prefetch_count: 0,
    prefetch_bytes: 100_000_000
  ]

config :ex_aws,
  region: "us-east-2"

import_config "#{Mix.env()}.exs"
