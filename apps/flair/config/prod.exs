use Mix.Config

config :flair,
  window_unit: :minute,
  window_length: 5,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats",
  table_name_quality: "dataset_quality"
