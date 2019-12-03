use Mix.Config

config :prestige,
  base_url: "http://127.0.0.1:8080",
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]

config :estuary,
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120]
