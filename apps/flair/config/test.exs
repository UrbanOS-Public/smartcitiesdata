use Mix.Config

config :flair,
  table_creator: nil,
  window_unit: :second,
  window_length: 1,
  message_timeout: 50,
  task_timeout: 50

config :prestige, base_url: "http://127.0.0.1:8080"
