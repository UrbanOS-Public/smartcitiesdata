use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/cota_streaming_consumer_web/views/.*(ex)$},
      ~r{lib/cota_streaming_consumer_web/templates/.*(eex)$}
    ]
  ]

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092, kafka: 9093],
    topics: ["test"],
    consumer_group: "cota-streaming-consumer",
    message_handler: CotaStreamingConsumer
  ],
  producer: [
    endpoints: [localhost: 9092, kafka: 9093],
    topics: ["test"]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
