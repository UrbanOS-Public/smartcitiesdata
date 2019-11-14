use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
redis_password = System.get_env("REDIS_PASSWORD", "")
all_redis_args = [host: redis_host, password: redis_password]
redix_args = Enum.filter(all_redis_args, fn
  {_, nil} -> false
  {_, ""} -> false
  _ -> true
end)
input_topic_prefix = System.get_env("INPUT_TOPIC_PREFIX")
output_topic_prefix = System.get_env("OUTPUT_TOPIC_PREFIX")
processor_stages = System.get_env("PROCESSOR_STAGES") || "1"
log_level = (System.get_env("LOG_LEVEL") || "warn") |> String.to_atom()

config :logger,
  level: log_level

if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      valkyrie_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "valkyrie",
          kubernetes_selector: "app.kubernetes.io/name=valkyrie",
          polling_interval: 10_000
        ]
      ]
    ]
end

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  config :valkyrie, :brook,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "valkyrie-events",
      consumer_config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Valkyrie.DatasetHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "valkyrie:view"
    ]
  ]

  config :yeet,
    topic: System.get_env("DLQ_TOPIC"),
    endpoint: endpoints

  config :valkyrie,
    elsa_brokers: endpoints,
    input_topic_prefix: input_topic_prefix,
    output_topic_prefix: output_topic_prefix,
    processor_stages: String.to_integer(processor_stages),
    topic_subscriber_config: [
      begin_offset: :earliest,
      offset_reset_policy: :reset_to_earliest,
      max_bytes: 1_000_000,
      min_bytes: 500_000,
      max_wait_time: 10_000
    ]
end
