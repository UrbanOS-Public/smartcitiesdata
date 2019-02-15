# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :forklift,
  timeout: 60_000,
  batch_size: 5_000,
  data_topic: "data-topic",
  registry_topic: "registry-topic"

config :prestige, base_url: "https://presto.dev.internal.smartcolumbusos.com"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: ["data-topic"],
    consumer_group: "forklift-group-1",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_latest,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition,
    rebalance_delay_ms: 1_000
  ],
  producer: [
    endpoints: [localhost: 9092],
    topics: ["data-topic"]
  ]

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_level: :debug

import_config "#{Mix.env()}.exs"
