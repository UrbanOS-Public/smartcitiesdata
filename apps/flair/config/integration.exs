use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

endpoint = [{to_char_list(host), 9094}]

config :flair,
  window_unit: :millisecond,
  window_length: 1

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["validated"]
  ]

config :kafka_ex,
  brokers: [{host, 9094}]

config :flair,
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
        kafka_create_topics: "streaming-validated:1:1",
        kafka_zookeeper_connect: "localhost:2181"
      ],
      wait_for: %{log: "Previous Leader Epoch was: -1", dwell: 1000, max_retries: 30},
      net: "flair-zookeeper"
    }
  ]
