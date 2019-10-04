use Mix.Config

config :e2e,
  divo: "test/docker-compose.yml",
  divo_wait: [dwell: 700, max_tries: 50],
  elsa_brokers: [{:localhost, 9092}]
