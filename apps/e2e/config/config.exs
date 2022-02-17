use Mix.Config

config :e2e,
  divo: "test/docker-compose.yml",
  divo_wait: [dwell: 1_000, max_tries: 120],
  elsa_brokers: [{:localhost, 9092}],
  ecto_repos: [Andi.Repo]

config :prestige, :session_opts,
  url: "http://localhost:8080",
  catalog: "hive",
  schema: "default",
  user: "foobar"
