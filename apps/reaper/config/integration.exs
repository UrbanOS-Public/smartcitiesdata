use Mix.Config

System.put_env("AWS_ACCESS_KEY_ID", "minioadmin")
System.put_env("AWS_ACCESS_KEY_SECRET", "minioadmin")

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoints = [{String.to_atom(host), 9092}]
redix_args = [host: host]

System.put_env("HOST", host)

config :logger,
  level: :info

bucket_name = "trino-hive-storage"

config :reaper,
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120],
  elsa_brokers: endpoints,
  output_topic_prefix: "raw",
  hosted_file_bucket: bucket_name,
  profiling_enabled: true

config :reaper, :brook,
  driver: %{
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "reaper-events",
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
      namespace: "reaper:view"
    ]
  },
  dispatcher: Brook.Dispatcher.Noop

config :reaper, Reaper.Scheduler,
  storage: Reaper.Quantum.Storage,
  overlap: false

config :reaper, Reaper.Quantum.Storage, redix_args

config :redix, :args, redix_args

config :ex_aws,
  debug_requests: true,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000
