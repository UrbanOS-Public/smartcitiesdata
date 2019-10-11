use Mix.Config

config :flair,
  table_creator: Flair.TableCreator,
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
