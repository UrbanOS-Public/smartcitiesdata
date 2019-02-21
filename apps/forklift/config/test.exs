use Mix.Config

config :forklift,
  timeout: 10,
  batch_size: 1,
  user: "foobar"

config :prestige, base_url: "https://kdp-kubernetes-data-platform-presto.kdp:8080"
