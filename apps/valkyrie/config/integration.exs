use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{to_char_list(host), 9094}]

config :valkyrie,
  divo: [
    zookeeper: %{
      image: "wurstmeister/zookeeper",
      ports: [
        {2181, 2181},
        {9094, 9094}
      ]
    },
    kafka: %{
      image: "wurstmeister/kafka:latest",
      env: [
        kafka_advertised_listeners: "INSIDE://:9092,OUTSIDE://#{host}:9094",
        kafka_listener_security_protocol_map: "INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT",
        kafka_listeners: "INSIDE://:9092,OUTSIDE://:9094",
        kafka_inter_broker_listener_name: "INSIDE",
        kafka_create_topics: "raw:1:1,validated:1:1",
        kafka_zookeeper_connect: "localhost:2181"
      ],
      wait_for: %{log: "Previous Leader Epoch was: -1", dwell: 1000, max_retries: 30},
      net: "valkyrie-zookeeper"
    }
  ]

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
