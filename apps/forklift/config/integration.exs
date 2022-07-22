use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

redix_args = [host: host]
endpoints = [{to_charlist(host), 9092}]

output_topic = "streaming-persisted"
bucket_name = "kdp-cloud-storage"

config :forklift,
  data_reader: Pipeline.Reader.DatasetTopicReader,
  topic_writer: Pipeline.Writer.TopicWriter,
  table_writer: Pipeline.Writer.S3Writer,
  retry_count: 100,
  retry_initial_delay: 100,
  retry_max_wait: 1_000 * 60 * 60,
  elsa_brokers: [{String.to_atom(host), 9092}],
  input_topic_prefix: "validated",
  s3_writer_bucket: "kdp-cloud-storage",
  output_topic: output_topic,
  producer_name: :"#{output_topic}-producer",
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 0,
    max_wait_time: 10_000
  ],
  profiling_enabled: true

config :forklift, :brook,
  instance: :forklift,
  event_processing_timeout: 10_000,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
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
      namespace: "forklift:view"
    ]
  ]

config :prestige, :session_opts,
  url: "http://#{host}:8080",
  catalog: "hive",
  schema: "default",
  user: "foobar"

config(:forklift, divo: "docker-compose.yml", divo_wait: [dwell: 1000, max_tries: 120])

config :redix,
  args: redix_args

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
