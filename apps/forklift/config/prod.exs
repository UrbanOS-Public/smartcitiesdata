import Config

config :forklift,
  compaction_retries: 100,
  compaction_backoff: 5_000

config :ex_aws,
  debug_requests: false

config :tzdata, :data_dir, "./tzdata"

config :logger,
  level: :info
