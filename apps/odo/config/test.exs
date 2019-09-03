use Mix.Config

config :odo,
  working_dir: "tmp",
  retry_delay: 500,
  retry_backoff: 2

config :odo, :brook,
  handlers: [Odo.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :ex_aws,
  access_key_id: "doesnt-matter",
  secret_access_key: "doesnt-matter"
