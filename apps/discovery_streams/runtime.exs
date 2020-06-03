use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
metrics_port = System.get_env("METRICS_PORT") |> String.to_integer()

config :discovery_streams,
  metrics_port: metrics_port

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  config :kaffe,
    consumer: [
      endpoints: endpoints,
      topics: [],
      consumer_group: "discovery-streams",
      message_handler: DiscoveryStreams.MessageHandler,
      offset_reset_policy: :reset_to_latest
    ]

  config :discovery_streams, :brook,
    instance: :discovery_streams,
    driver: [
      module: Brook.Driver.Kafka,
      init_arg: [
        endpoints: endpoints,
        topic: "event-stream",
        group: "discovery_streams-events",
        config: [
          begin_offset: :earliest,
          offset_reset_policy: :reset_to_earliest
        ]
      ]
    ],
    handlers: [DiscoveryStreams.EventHandler],
    storage: [
      module: Brook.Storage.Redis,
      init_arg: [
        redix_args: [host: redis_host],
        namespace: "discovery_streams:view"
      ]
    ]
end

if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      consumer_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "discovery_streams",
          kubernetes_selector: "app=discovery-streams",
          polling_interval: 10_000
        ]
      ]
    ]
end
