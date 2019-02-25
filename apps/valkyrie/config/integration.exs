use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{to_charlist(host), 9094}]

config :valkyrie,
  docker: %{
    version: "2",
    services: %{
      zookeeper: %{
        image: "wurstmeister/zookeeper",
        ports: ["2181:2181"]
      },
      kafka: %{
        image: "wurstmeister/kafka",
        depends_on: ["zookeeper"],
        ports: ["9094:9094"],
        environment: %{
          "KAFKA_ADVERTISED_LISTENERS" => "INSIDE://:9092,OUTSIDE://#{host}:9094",
          "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP" => "INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT",
          "KAFKA_LISTENERS" => "INSIDE://:9092,OUTSIDE://:9094",
          "KAFKA_INTER_BROKER_LISTENER_NAME" => "INSIDE",
          "KAFKA_CREATE_TOPICS" => "raw:1:1,validated:1:1",
          "KAFKA_ZOOKEEPER_CONNECT" => "zookeeper:2181"
        },
        volumes: ["/var/run/docker.sock:/var/run/docker.sock"]
      }
    }
  },
  # Leader election of Kafka cluster succeeded
  docker_wait_for: "Previous Leader Epoch was: -1"

config :kaffe,
  consumer: [
    endpoints: endpoint,
    topics: ["raw"],
    consumer_group: "valkyrie-consumer-group",
    message_handler: Valkyrie.MessageHandler,
    start_with_earliest_message: true
  ],
  producer: [
    endpoints: endpoint,
    topics: ["validated"],
    partition_strategy: :md5
  ]
