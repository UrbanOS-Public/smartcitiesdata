use Mix.Config

required_envars = [
  "REDIS_HOST",
  "KAFKA_BROKERS",
  "OUTPUT_TOPIC_PREFIX",
  "DLQ_TOPIC",
  "HOSTED_FILE_BUCKET",
  "SECRETS_ENDPOINT"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

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

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

normalize_secrets_endpoint = fn
  nil -> nil
  endpoint ->
    cond do
      String.starts_with?(endpoint, "http://") or String.starts_with?(endpoint, "https://") ->
        endpoint
      true ->
        "http://#{endpoint}"
    end
end

secrets_endpoint_raw = System.get_env("SECRETS_ENDPOINT")
IO.puts("DEBUG: SECRETS_ENDPOINT raw from env: #{inspect(secrets_endpoint_raw)}")
secrets_endpoint = normalize_secrets_endpoint.(secrets_endpoint_raw)
IO.puts("DEBUG: SECRETS_ENDPOINT after normalization: #{inspect(secrets_endpoint)}")

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

config :reaper,
  secrets_endpoint: secrets_endpoint,
  elsa_brokers: endpoints,
  output_topic_prefix: System.get_env("OUTPUT_TOPIC_PREFIX"),
  download_dir: System.get_env("DOWNLOAD_DIR") || "/downloads/",
  hosted_file_bucket: System.get_env("HOSTED_FILE_BUCKET") || "hosted-dataset-files",
  profiling_enabled: System.get_env("PROFILING_ENABLED") == "true"

config :reaper, :brook,
  driver: %{
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "reaper-event-stream",
      consumer_config: [
        begin_offset: :earliest,
        offset_reset_policy: :reset_to_earliest
      ]
    ]
  },
  handlers: [Reaper.Event.EventHandler],
  storage: %{
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "reaper:view",
      event_limits: %{
        "data:extract:start" => 100,
        "data:extract:end" => 100,
        "data:ingest:start" => 100,
        "error:ingestion:update" => 100,
        "ingestion:update" => 100,
        "ingestion:delete" => 100
      }
    ]
  },
  dispatcher: Brook.Dispatcher.Noop,
  event_processing_timeout: 10_000

config :reaper, Reaper.Scheduler,
  storage: Reaper.Quantum.Storage,
  global: true,
  overlap: false

# Configure Quantum storage to use the same Redis connection as main app
# This passes the redix_args keyword list (host, port, password, ssl) to Quantum.Storage.Connection
config :reaper, Reaper.Quantum.Storage, redix_args

config :redix, :args,
  redix_args

config :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      endpoints: endpoints,
      topic: "streaming-dead-letters"
    ]
  ]

config :ex_aws,
  region: System.get_env("AWS_REGION") || "us-west-2"

config :telemetry_event,
  metrics_port: System.get_env("METRICS_PORT") |> String.to_integer()
