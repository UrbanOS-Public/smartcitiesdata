use Mix.Config

System.put_env("AWS_ACCESS_KEY_ID", "testing_access_key")
System.put_env("AWS_ACCESS_KEY_SECRET", "testing_secret_key")

config :odo,
  working_dir: "/tmp",
  retry_delay: 50,
  retry_backoff: 2

config :odo, :brook,
  handlers: [Odo.Event.EventHandler, Odo.Support.TestEventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ]

config :ex_aws,
  access_key_id: "doesnt-matter",
  secret_access_key: "doesnt-matter"
