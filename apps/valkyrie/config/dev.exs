use Mix.Config

host = "localhost"
raw_topic = "raw"
validated_topic = "validated"
dead_letter_queue = "streaming-dead-letters"

System.put_env("HOST", host)

endpoint = [{to_charlist(host), 9092}]

config :kaffe,
  consumer: [
    endpoints: endpoint,
    topics: [raw_topic],
    consumer_group: "valkyrie-group",
    message_handler: Valkyrie.MessageHandler,
    offset_reset_policy: :reset_earliest,
    start_with_earliest_message: true,
    worker_allocation_strategy: :worker_per_topic_partition
  ],
  producer: [
    endpoints: endpoint,
    topics: [validated_topic]
  ]

config :yeet,
  topic: dead_letter_queue,
  endpoint: endpoint
