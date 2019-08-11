use Mix.Config

config :odo,
  working_dir: "tmp"

config :brook, :config,
  handlers: [Odo.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :ex_aws,
  access_key_id: "doesnt-matter",
  secret_access_key: "doesnt-matter"
