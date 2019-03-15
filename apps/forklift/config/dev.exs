use Mix.Config

data_topic = "streaming-transformed"
registry_topic = "dataset-registry"

config :forklift,
  timeout: 15_000,
  batch_size: 5_000,
  user: "forklift"

config :prestige, base_url: "http://127.0.0.1:8080"

config :redix,
  host: "localhost"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9094],
    topics: [data_topic, registry_topic],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition
  ]
