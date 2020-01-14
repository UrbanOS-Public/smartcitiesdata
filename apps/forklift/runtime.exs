use Mix.Config

required_envars = [
  "REDIS_HOST",
  "KAFKA_BROKERS",
  "DATA_TOPIC_PREFIX",
  "PRESTO_USER",
  "PRESTO_URL",
  "OUTPUT_TOPIC"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
get_redix_args = fn (host, password) ->
	[host: host, password: password]
	|> Enum.filter(fn
		{_, nil} -> false
		{_, ""} -> false
		_ -> true
	end)
end
redix_args = get_redix_args.(System.get_env("REDIS_HOST"), System.get_env("REDIS_PASSWORD"))

topic = System.get_env("DATA_TOPIC_PREFIX")
output_topic = System.get_env("OUTPUT_TOPIC")
metrics_port = System.get_env("METRICS_PORT") |> String.to_integer()

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {to_charlist(host), String.to_integer(port)} end)

elsa_brokers =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :forklift,
  elsa_brokers: elsa_brokers,
  input_topic_prefix: topic,
  output_topic: output_topic,
  producer_name: :"#{output_topic}-producer",
  metrics_port: metrics_port,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 10_000
  ]

config :forklift, :brook,
  instance: :forklift,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: elsa_brokers,
      topic: "event-stream",
      group: "forklift-events",
      consumer_config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Forklift.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "forklift:view"
    ]
  ]

config :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      endpoints: endpoints,
      topic: "streaming-dead-letters"
    ]
  ]

config :prestige, :session_opts,
  url: System.get_env("PRESTO_URL"),
  user: System.get_env("PRESTO_USER")

config :redix,
  args: redix_args

if System.get_env("COMPACTION_SCHEDULE") do
  config :forklift, Forklift.Quantum.Scheduler,
    jobs: [
      compactor: [
        schedule: System.get_env("COMPACTION_SCHEDULE"),
        task: {Forklift.DataWriter, :compact_datasets, []},
        timezone: "America/New_York"
      ]
    ]
end

if System.get_env("RUN_IN_KUBERNETES") do
  config :libcluster,
    topologies: [
      forklift_cluster: [
        strategy: Elixir.Cluster.Strategy.Kubernetes,
        config: [
          mode: :dns,
          kubernetes_node_basename: "forklift",
          kubernetes_selector: "app.kubernetes.io/name=forklift",
          polling_interval: 10_000
        ]
      ]
    ]
end
