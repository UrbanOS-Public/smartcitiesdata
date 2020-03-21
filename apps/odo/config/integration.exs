use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

config :logger,
  level: :info

bucket_name = "kdp-cloud-storage"
endpoints = [{String.to_atom(host), 9092}]

config :odo,
  kafka_broker: endpoints,
  hosted_file_bucket: bucket_name,
  working_dir: "tmp",
  retry_delay: 500,
  retry_backoff: 2,
  metrics_port: 9003

config :ex_aws,
  debug_requests: true,
  access_key_id: "testing_access_key",
  secret_access_key: "testing_secret_key",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000

config :odo, :brook,
  instance: :odo_brook,
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
  handlers: [Odo.EventHandler],
  storage: %{
    module: Brook.Storage.Redis,
    init_arg: [redix_args: [host: host], namespace: "odo:view"]
  }
