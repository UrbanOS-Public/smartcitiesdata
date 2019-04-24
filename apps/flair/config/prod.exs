use Mix.Config

config :flair,
  window_unit: :minute,
  window_length: 5,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000

config :logger,
  level: :warn
