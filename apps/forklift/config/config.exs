# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

data_topic_prefix = "transformed"

config :yeet,
  topic: "streaming-dead-letters",
  endpoint: [localhost: 9094]

config :forklift,
  cache_processing_batch_size: 1_000,
  message_processing_cadence: 10_000,
  number_of_empty_reads_to_delete: 50,
  data_topic_prefix: data_topic_prefix,
  output_topic: "streaming-persisted"

config :kaffe,
  consumer: [
    topics: [],
    consumer_group: "forklift-group",
    message_handler: Forklift.Messages.MessageHandler,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 10_000,
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
