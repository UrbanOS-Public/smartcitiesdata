# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

data_topic = "streaming-transformed" ## Warning: This is overriding the release configuration
registry_topic = "dataset-registry"

config :forklift,
  timeout: 60_000,
  batch_size: 5_000,
  data_topic: data_topic,
  registry_topic: registry_topic

config :prestige, base_url: "https://presto.dev.internal.smartcolumbusos.com"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: [data_topic, registry_topic],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition,
  ]

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_level: :debug

import_config "#{Mix.env()}.exs"
