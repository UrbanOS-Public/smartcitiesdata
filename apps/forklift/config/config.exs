# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :forklift,
  timeout: 60_000,
  batch_size: 5_000,
  data_topic: "data-topic",
  registry_topic: "registry-topic"

# config :prestige, base_url: "https://presto.dev.internal.smartcolumbusos.com"
config :prestige, base_url: "http://localhost:8080"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: ["data-topic"],
    consumer_group: "forklift-group-1",
    message_handler: Forklift.MessageProcessor,
    # offset_reset_policy: :reset_to_latest,
    # max_bytes: 500_000,
    worker_allocation_strategy: :worker_per_topic_partition
  ]

    import_config "#{Mix.env()}.exs"
