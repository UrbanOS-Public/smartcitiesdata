use Mix.Config

# data_topic = "streaming-transformed"
data_topic = "streaming-validated"

config :logger,
  level: :info

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: [data_topic],
    consumer_group: "flair-consumer-group",
    message_handler: Flair.MessageProcessor,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition
  ]
