use Mix.Config
# We should turn this into a repo to share with Reaper
import_config "../test/integration/divo_minio.ex"

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

config :logger,
  level: :info

bucket_name = "hosted-dataset-files"
endpoint = [{host, 9092}]

config :odo,
  divo: [
    {DivoKafka, [create_topics: "event-stream:1:1", outside_host: host]},
    DivoRedis,
    {Reaper.DivoMinio, [bucket_name: bucket_name]}
  ],
  divo_wait: [dwell: 1000, max_tries: 120],
  hosted_file_bucket: bucket_name,
  kafka_broker: endpoint,
  working_dir: "tmp"

config :ex_aws,
  debug_requests: true,
  access_key_id: "access_key_testing",
  secret_access_key: "secret_key_testing",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000

config :brook, :config,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "odo-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Odo.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: [host: host], namespace: "odo:view"]
  ]
