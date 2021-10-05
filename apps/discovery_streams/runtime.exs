use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")

get_redix_args = fn host, password, port ->
  port = if (port == ""), do: port, else: String.to_integer(port)
  [host: host, password: password, port: port]
  |> Enum.filter(fn
    {_, nil} -> false
    {_, ""} -> false
    _ -> true
  end)
end

redix_args = get_redix_args.(System.get_env("REDIS_HOST"), System.get_env("REDIS_PASSWORD"), System.get_env("REDIS_PORT"))

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)


  config :discovery_streams, endpoints: endpoints

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
    handlers: [DiscoveryStreams.Event.EventHandler],
    storage: [
      module: Brook.Storage.Redis,
      init_arg: [
        redix_args: redix_args,
        namespace: "discovery_streams:view",
        event_limits: %{
          "dataset:update" => 100,
          "dataset:delete" => 100,
          "data:ingest:start" => 100
        }
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

config :telemetry_event,
  metrics_port: System.get_env("METRICS_PORT") |> String.to_integer(),
  metrics_options: [
    [
      metric_name: "records.count",
      tags: [:app, :dataset_id, :PodHostname, :type],
      metric_type: :sum
    ]
  ]
