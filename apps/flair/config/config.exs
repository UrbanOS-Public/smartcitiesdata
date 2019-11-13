use Mix.Config

config :flair,
  table_writer: Pipeline.Writer.TableWriter,
  data_topic: "persisted"

config :logger,
  level: :info

config :prestige,
  headers: [
    user: "presto",
    catalog: "hive",
    schema: "default"
  ]

import_config "#{Mix.env()}.exs"
