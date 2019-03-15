use Mix.Config

config :forklift,
  # To ensure that MessageWriter never starts while testing
  timeout: 1_000_000_000,
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
