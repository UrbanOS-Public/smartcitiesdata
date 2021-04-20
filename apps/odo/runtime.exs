use Mix.Config

required_envars = [
  "KAFKA_BROKERS",
  "REDIS_HOST"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :odo,
  working_dir: System.get_env("WORKING_DIR") || "/downloads/",
  secrets_endpoint: System.get_env("SECRETS_ENDPOINT"),
  hosted_file_bucket: System.get_env("HOSTED_FILE_BUCKET") || "hosted-dataset-files",
  retry_delay: 1_000,
  retry_backoff: 5

config :ex_aws,
  region: System.get_env("AWS_REGION") || "us-west-2"

config :odo, :brook,
  driver: %{
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "odo-event-stream",
      consumer_config: [
        begin_offset: :earliest
      ]
    ]
  },
  handlers: [Odo.Event.EventHandler],
  storage: %{
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: [host: redis_host],
      namespace: "odo:view",
      event_limits: %{
        "file:ingest:end" => 100,
        "error:file:ingest" => 100
      }
    ]
  }

  config :telemetry_event,
    metrics_port: System.get_env("METRICS_PORT") |> String.to_integer(),
    metrics_options: [
      [
        metric_name: "file_conversion_success.gauge",
        tags: [:app, :dataset_id, :file, :start],
        metric_type: :last_value
      ],
      [
        metric_name: "file_conversion_duration.gauge",
        tags: [:app, :dataset_id, :file, :start],
        metric_type: :last_value
      ]
    ]
