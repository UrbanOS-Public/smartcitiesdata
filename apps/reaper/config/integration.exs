use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{to_charlist(host), 9094}]

webserver_host = host
webserver_port = 7000

config :logger,
  level: :error

config :reaper,
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
          "KAFKA_CREATE_TOPICS" => "dataset-registry:1:1,streaming-raw:1:1",
          "KAFKA_ZOOKEEPER_CONNECT" => "zookeeper:2181"
        },
        volumes: ["/var/run/docker.sock:/var/run/docker.sock"]
      },
      redis: %{
        image: "redis",
        ports: ["6379:6379"]
      },
      webserver: %{
        build: %{
          context: "#{File.cwd!()}/test/support/",
          dockerfile: "Dockerfile.webserver"
        },
        ports: ["#{webserver_port}:80"]
      }
    }
  },
  # Leader election of Kafka cluster succeeded
  docker_wait_for: "Previous Leader Epoch was: -1",
  webserver_host: webserver_host,
  webserver_port: webserver_port

config :kaffe,
  consumer: [
    endpoints: endpoint,
    topics: ["dataset-registry"],
    consumer_group: "reaper-consumer-group",
    message_handler: Reaper.MessageHandler,
    start_with_earliest_message: true,
    async_message_ack: true
  ],
  producer: [
    endpoints: endpoint,
    topics: ["streaming-raw"],
    partition_strategy: :md5
  ]

config :redix,
  host: host
