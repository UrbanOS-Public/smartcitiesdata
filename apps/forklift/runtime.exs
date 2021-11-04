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
s3_writer_bucket = System.get_env("S3_WRITER_BUCKET")
secrets_endpoint = System.get_env("SECRETS_ENDPOINT")

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
  s3_writer_bucket: s3_writer_bucket,
  secrets_endpoint: secrets_endpoint,
  producer_name: :"#{output_topic}-producer",
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 10_000_000,
    min_bytes: 5_000_000,
    max_wait_time: 60_000
  ],
  profiling_enabled: System.get_env("PROFILING_ENABLED") == "true"

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
  handlers: [Forklift.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "forklift:view",
      event_limits: %{
        "dataset:delete" => 100,
        "dataset:update" => 100,
        "data:write:complete" => 100,
        "data:ingest:start" => 100,
        "data:ingest:end" => 100,
        "error:dataset:update" => 100
      }
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

config :ex_aws,
  region: System.get_env("AWS_REGION") || "us-west-2"

if System.get_env("AWS_ACCESS_KEY_ID") do
  config :ex_aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")
end

if System.get_env("S3_HOST_NAME") do
  config :ex_aws, :s3,
    scheme: "http://",
    region: "local",
    host: %{
      "local" => System.get_env("S3_HOST_NAME")
    },
    port: System.get_env("S3_PORT") |> String.to_integer()
end

if System.get_env("COMPACTION_SCHEDULE") do
  special_compaction_datasets_string = System.get_env("SPECIAL_COMPACTION_DATASETS") || ""
  special_compaction_datasets = String.split(special_compaction_datasets_string, ",")
  config :forklift, Forklift.Quantum.Scheduler,
    jobs: [
      compactor: [
        schedule: System.get_env("COMPACTION_SCHEDULE"),
        task: {Forklift.DataWriter, :compact_datasets, [special_compaction_datasets]},
        timezone: "America/New_York"
      ],
      data_migrator: [
        schedule: System.get_env("COMPACTION_SCHEDULE"),
        task: {Forklift.Jobs.DataMigration, :run, [special_compaction_datasets]},
        timezone: "America/New_York"
      ],
      partitioned_compactor: [
        schedule: "45 0 * * *",
        task: {Forklift.Jobs.PartitionedCompaction, :run, [special_compaction_datasets]},
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

config :telemetry_event,
  metrics_port: System.get_env("METRICS_PORT") |> String.to_integer(),
  add_metrics: [:dead_letters_handled_count],
  metrics_options: [
    [
      metric_name: "dataset_compaction_duration_total.duration",
      tags: [:app, :system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "dataset_record_total.count",
      tags: [:system_name],
      metric_type: :last_value
    ],
    [
      metric_name: "forklift_compaction_failure.status",
      tags: [:dataset_id],
      metric_type: :last_value
    ],
    [
      metric_name: "forklift_migration_failure.status",
      tags: [:dataset_id],
      metric_type: :last_value
    ]
  ]
