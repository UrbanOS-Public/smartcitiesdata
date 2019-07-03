use Mix.Config

data_topic_prefix = "streaming-transformed"

config :forklift,
  message_processing_cadence: 15_000,
  user: "forklift"

config :prestige, base_url: "http://127.0.0.1:8080"

config :redix,
  host: "localhost"

config :husky,
  pre_commit: "./scripts/git_pre_commit_hook.sh"
