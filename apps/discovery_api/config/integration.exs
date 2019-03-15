use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoints = [{to_char_list(host), 9094}]

config :discovery_api, DiscoveryApiWeb.Endpoint,
  url: [host: "discoveryapi.integrationtests.com", port: {:system, "PORT"}]

config :redix,
  host: host

config :kaffe,
  producer: [
    endpoints: endpoints,
    topics: ["dataset-registry"],
    max_retries: 30,
    retry_backoff_ms: 500
  ],
  consumer: [
    endpoints: endpoints,
    topics: ["dataset-registry"],
    consumer_group: "discovery-dataset-consumer",
    message_handler: DiscoveryApi.Data.DatasetEventListener,
    rebalance_delay_ms: 10_000,
    start_with_earliest_message: true
  ]

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :discovery_api,
  divo: [
    zookeeper: %{
      image: "wurstmeister/zookeeper",
      ports: [{2181, 2181}, {9094, 9094}]
    },
    kafka: %{
      image: "wurstmeister/kafka:latest",
      env: [
        kafka_advertised_listeners: "INSIDE://:9092,OUTSIDE://#{host}:9094",
        kafka_listener_security_protocol_map: "INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT",
        kafka_listeners: "INSIDE://:9092,OUTSIDE://:9094",
        kafka_inter_broker_listener_name: "INSIDE",
        kafka_create_topics: "dataset-registry:1:1",
        kafka_zookeeper_connect: "localhost:2181"
      ],
      wait_for: %{log: "Previous Leader Epoch was: -1", dwell: 1000, max_retries: 60},
      net: "discovery_api-zookeeper"
    },
    redis: %{
      image: "redis:latest",
      ports: [{6379, 6379}]
    }
  ]

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end
