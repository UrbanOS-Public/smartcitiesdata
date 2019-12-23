use Mix.Config

connection = :estuary_elsa

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_schema_name: "event_stream",
  event_stream_table_name: "history",
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  retry_count: 10,
  retry_initial_delay: 100,
  connection: connection

import_config "#{Mix.env()}.exs"
