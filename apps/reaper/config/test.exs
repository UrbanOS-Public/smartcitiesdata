use Mix.Config

config :logger,
  level: :info

config :phoenix, :json_library, Jason

config :yeet,
  topic: "dead-letters"

config :reaper,
  output_topic_prefix: "raw",
  produce_retries: 2,
  produce_timeout: 10,
  secrets_endpoint: "http://vault:8200"

config :reaper, :brook,
  handler: [Reaper.Event.Handler],
  storage: [
    modules: Brook.Storage.Ets,
    init_arg: []
  ],
  hosted_file_bucket: "hosted-dataset-files"
