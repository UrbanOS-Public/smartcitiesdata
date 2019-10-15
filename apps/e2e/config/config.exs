use Mix.Config

config :e2e,
  divo: "test/docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120],
  elsa_brokers: [{:localhost, 9092}]
