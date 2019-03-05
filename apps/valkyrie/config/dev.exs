use Mix.Config

endpoints = [localhost: 9094]
raw_topic = "streaming-raw"
validated_topic = "streaming-validated"

config :kaffe,
  consumer: [
    endpoints: endpoints,
    topics: [raw_topic],
    consumer_group: "valkyrie-group",
    message_handler: Valkyrie.MessageHandler,
    offset_reset_policy: :reset_earliest,
    start_with_earliest_message: true,
    worker_allocation_strategy: :worker_per_topic_partition
  ],
  producer: [
    endpoints: endpoints,
    topics: [validated_topic]
  ]
