use Mix.Config

endpoints = [localhost: 9092]

config :prestige,
  base_url: "http://127.0.0.1:8080",
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]

config :estuary,
  elsa_endpoint: [localhost: 9092],
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120]

config :logger, level: :warn

config :yeet,
  topic: "dead-letters",
  endpoint: endpoints
