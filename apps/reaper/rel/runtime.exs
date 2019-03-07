use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")

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
      topics: [System.get_env("FROM_TOPIC")],
      consumer_group: "reaper-consumer-group",
      message_handler: Reaper.MessageHandler,
      offset_reset_policy: :reset_to_earliest,
      start_with_earliest_message: true,
      async_message_ack: false
    ],
    producer: [
      endpoints: endpoints,
      topics: [System.get_env("TO_TOPIC")],
      partition_strategy: :md5
    ]
end

if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      reaper_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "reaper",
          kubernetes_selector: "app.kubernetes.io/name=reaper",
          polling_interval: 10_000
        ]
      ]
    ]
end

if(System.get_env("REDIS_HOST")) do
  config :redix,
    host: System.get_env("REDIS_HOST")
end
