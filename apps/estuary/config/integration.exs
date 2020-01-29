use Mix.Config

endpoints = [localhost: 9092]

config :prestige, :session_opts,
  url: "http://127.0.0.1:8080"

config :estuary,
  endpoints: endpoints,
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1000, max_tries: 120],
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  topic: "event-stream"

config :logger, level: :warn
