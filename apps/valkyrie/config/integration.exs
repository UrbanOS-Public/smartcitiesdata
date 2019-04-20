use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

endpoint = [{to_charlist(host), 9092}]

config :logger,
  level: :info

config :valkyrie,
  divo: [
    {DivoKafka, [create_topics: "raw:1:1,validated:1:1,dead-letters:1:1", outside_host: host]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50]

config :kaffe,
  consumer: [
    endpoints: endpoint,
    topics: ["raw"],
    consumer_group: "valkyrie-consumer-group",
    message_handler: Valkyrie.MessageHandler,
    offset_reset_policy: :reset_to_earliest,
    rebalance_delay_ms: 1000,
    worker_allocation_strategy: :worker_per_topic_partition,
    start_with_earliest_message: true
  ],
  producer: [
    endpoints: endpoint,
    topics: ["validated"],
    partition_strategy: :md5
  ]

config :yeet,
  topic: "dead-letters",
  endpoint: endpoint

config :smart_city_registry,
  redis: [
    host: host
  ]
