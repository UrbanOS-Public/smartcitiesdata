use Mix.Config

config :kaffe,
  consumer: [
    consumer_group: "valkyrie-consumer-group",
    message_handler: Valkyrie.MessageHandler,
    offset_reset_policy: :reset_to_earliest,
    rebalance_delay_ms: 1000,
    worker_allocation_strategy: :worker_per_topic_partition,
    start_with_earliest_message: true
  ],
  producer: [
    partition_strategy: :md5
  ]
