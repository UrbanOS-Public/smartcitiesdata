use Mix.Config

config :flair,
  data_topic: "persisted"

config :logger,
  level: :info

config :kafka_ex,
  brokers: [
    {"localhost", 9094}
  ],
  consumer_group: "flair-consumer-group",
  auto_offset_reset: :latest

config :prestige,
  base_url: "https://presto.dev.internal.smartcolumbusos.com",
  headers: [
    user: "presto",
    catalog: "hive",
    schema: "default"
  ]

import_config "#{Mix.env()}.exs"
