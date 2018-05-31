use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :logger, level: :info

config :kaffe,
  consumer: [
    endpoints: [kafka: 9093],
    topics: [System.get_env("COTA_DATA_TOPIC")],
    consumer_group: "cota-streaming-consumer",
    message_handler: CotaStreamingConsumer
  ]
