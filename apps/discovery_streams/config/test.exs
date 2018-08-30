use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  http: [port: 4001],
  server: false

# Don't start kaffe consumer for unit tests
config :cota_streaming_consumer, :children, []
