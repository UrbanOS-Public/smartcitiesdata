use Mix.Config

config :cota_streaming_consumer, CotaStreamingConsumerWeb.Endpoint,
  http: [port: 4001],
  server: false

config :kaffe,
  consumer: [
    topics: ["shuttle-position", "cota-vehicle-positions"]
  ]
