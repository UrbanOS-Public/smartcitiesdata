use Mix.Config

config :forklift,
  # To ensure that MessageWriter never starts while testing
  message_processing_cadence: 1_000_000_000,
  cache_processing_batch_size: 1_000,
  user: "foobar"

config :prestige,
  base_url: "https://kdp-kubernetes-data-platform-presto.kdp:8080",
  headers: [
    user: "foobar"
  ]

config :kaffe,
  consumer: [
    endpoints: nil
  ]
