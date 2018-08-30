use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  debug_errors: true,
  check_origin: false,
  watchers: []

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092, kafka: 9093],
    topics: ["test"],
    consumer_group: "cota-streaming-consumer",
    message_handler: CotaStreamingConsumer,
    offset_reset_policy: :reset_to_latest
  ],
  producer: [
    endpoints: [localhost: 9092, kafka: 9093],
    topics: ["test"]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :ex_aws,
  debug_requests: true
