use Mix.Config

config :estuary,
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]
