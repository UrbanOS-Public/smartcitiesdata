use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")


get_redix_args = fn (host, port, password, ssl) ->
  [host: host, port: port, password: password, ssl: ssl]
  |> Enum.filter(fn
    {_, nil} -> false
    {_, ""} -> false
    _ -> true
  end)
end

ssl_enabled = Regex.match?(~r/^true$/i, System.get_env("REDIS_SSL"))
{redis_port, ""} = Integer.parse(System.get_env("REDIS_PORT"))

redix_args = get_redix_args.(System.get_env("REDIS_HOST"), redis_port, System.get_env("REDIS_PASSWORD"), ssl_enabled)

input_topic_prefix = System.get_env("INPUT_TOPIC_PREFIX")
output_topic_prefix = System.get_env("OUTPUT_TOPIC_PREFIX")
processor_stages = System.get_env("PROCESSOR_STAGES") || "1"
profiling_enabled = System.get_env("PROFILING_ENABLED") == "true"


if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      alchemist_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "alchemist",
          kubernetes_selector: "app.kubernetes.io/name=alchemist",
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

  config :alchemist, :brook,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "alchemist-events",
      consumer_config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Alchemist.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "alchemist:view",
      event_limits: %{
        "ingestion:update" => 100,
        "ingestion:delete" => 100
      }
    ]
  ]

  config :alchemist,
    elsa_brokers: endpoints,
    input_topic_prefix: input_topic_prefix,
    output_topic_prefix: output_topic_prefix,
    processor_stages: String.to_integer(processor_stages)

  config :dead_letter,
    driver: [
      module: DeadLetter.Carrier.Kafka,
      init_args: [
        endpoints: endpoints,
        topic: "streaming-dead-letters"
      ]
    ]
end

config :alchemist,
  profiling_enabled: profiling_enabled

config :telemetry_event,
  metrics_port: System.get_env("METRICS_PORT") |> String.to_integer(),
  add_metrics: [:dead_letters_handled_count]
