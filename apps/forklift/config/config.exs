# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

data_topic = "streaming-transformed"

config :forklift,
  cache_processing_batch_size: 20_000,
  message_processing_cadence: 10_000,
  data_topic: data_topic

config :kaffe,
  consumer: [
    topics: [data_topic],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition
  ]

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_level: :debug

import_config "#{Mix.env()}.exs"

config :prestige,
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]
