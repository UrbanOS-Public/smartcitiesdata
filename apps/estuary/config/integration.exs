use Mix.Config

endpoints = [localhost: 9092]

config :prestige,
  base_url: "http://127.0.0.1:8080",
  headers: [
    user: "estuary",
    catalog: "hive",
    schema: "event_stream"
  ]

config :estuary,
  endpoints: [localhost: 9092],
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120],
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter

config :logger, level: :warn

config :estuary, :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      name: :estuary_dead_letters,
      endpoints: endpoints,
      topic: "dead-letters"
    ]
  ]
