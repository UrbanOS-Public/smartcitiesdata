use Mix.Config

# data_topic = "streaming-transformed"
data_topic = "streaming-validated"

config :logger,
  level: :info

config :kafka_ex,
  brokers: [
    {"localhost", 9094}
  ],
  consumer_group: "flair-consumer-group"

config :prestige,
  base_url: "https://presto.dev.internal.smartcolumbusos.com",
  headers: [
    user: "presto",
    catalog: "hive",
    schema: "default"
  ]

import_config "#{Mix.env()}.exs"
