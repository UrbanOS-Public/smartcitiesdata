use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

redis_args = [host: host]
endpoints = [{to_charlist(host), 9092}]

output_topic = "streaming-persisted"

config :forklift,
  data_reader: Pipeline.Reader.DatasetTopicReader,
  topic_writer: Pipeline.Writer.TopicWriter,
  table_writer: Pipeline.Writer.TableWriter,
  retry_count: 10,
  retry_initial_delay: 100,
  elsa_brokers: [{String.to_atom(host), 9092}],
  input_topic_prefix: "transformed",
  output_topic: output_topic,
  producer_name: :"#{output_topic}-producer",
  metrics_port: 9002,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 0,
    max_wait_time: 10_000
  ]

config :forklift, :brook,
  instance: :forklift,
  event_processing_timeout: 10_000,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "forklift-events",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Forklift.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redis_args,
      namespace: "forklift:view"
    ]
  ]

config :forklift, :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      name: :forklift_dead_letters,
      endpoints: endpoints,
      topic: "dead-letters"
    ]
  ]

config :prestige,
  base_url: "http://#{host}:8080",
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]

config(:forklift, divo: "docker-compose.yml", divo_wait: [dwell: 1000, max_tries: 120])

config :redix,
       args: redis_args
