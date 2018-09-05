use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint, check_origin: false

config :kaffe,
  consumer: [
    # endpoints: Set in application.ex
    # topics: Set in application.ex
    consumer_group: "cota-streaming-consumer",
    message_handler: CotaStreamingConsumer,
    offset_reset_policy: :reset_to_latest
  ]

config :streaming_metrics,
  collector: StreamingMetrics.AwsMetricCollector

config :ex_aws,
  debug_requests: false
