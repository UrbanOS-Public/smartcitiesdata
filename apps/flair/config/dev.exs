import Config

config :prestige, :session_opts, url: "http://127.0.0.1:8080"

config :flair,
  window_unit: :minute,
  window_length: 5,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats"
