use Mix.Config

config :forklift,
  timeout: 15_000,
  batch_size: 5_000,
  user: "forklift"

config :prestige, base_url: "https://127.0.0.1:8080"
