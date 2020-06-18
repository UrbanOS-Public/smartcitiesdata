use Mix.Config

config :logger,
  level: :warn

config :phoenix, :json_library, Jason

config :reaper,
  output_topic_prefix: "raw",
  produce_retries: 2,
  produce_timeout: 10,
  secrets_endpoint: "http://vault:8200",
  hosted_file_bucket: "hosted-dataset-files",
  task_delay_on_failure: 1_000

config :reaper, :brook,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [Reaper.Event.Handler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  dispatcher: Brook.Dispatcher.Noop

config :telemetry_event, metrics_port: 9004
