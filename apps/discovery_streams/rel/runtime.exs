use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  config :kaffe, consumer: [
    endpoints: endpoints,
    topics: [],
    consumer_group: "discovery-streams",
    message_handler: DiscoveryStreams.MessageHandler,
    offset_reset_policy: :reset_to_latest
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
