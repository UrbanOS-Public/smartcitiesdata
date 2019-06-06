use Mix.Config

data_topic_prefix = "streaming-transformed"

config :forklift,
  message_processing_cadence: 15_000,
  user: "forklift"

config :prestige, base_url: "http://127.0.0.1:8080"

config :redix,
  host: "localhost"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9094],
    topics: [data_topic_prefix],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageHandler,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition
  ]
