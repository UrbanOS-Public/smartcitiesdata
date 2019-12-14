use Mix.Config

config :estuary,
  elsa_endpoint: [localhost: 9092],
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120]

config :logger, level: :warn
