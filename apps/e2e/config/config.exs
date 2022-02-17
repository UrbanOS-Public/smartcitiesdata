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

config :e2e, :brook,
  driver: %{
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: [{"streaming-service-kafka-bootstrap", 9092}],
      topic: "event-stream",
      group: "e2e-events",
      consumer_config: [
        begin_offset: :earliest,
        offset_reset_policy: :reset_to_earliest
      ]
    ]
  },
  storage: %{
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: [host: "127.0.0.1"],
      namespace: "reaper:view"
    ]
  },
  dispatcher: Brook.Dispatcher.Noop
