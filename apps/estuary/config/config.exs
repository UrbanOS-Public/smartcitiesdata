use Mix.Config

connection = :estuary_elsa

config :estuary,
  topic: "event-stream",
  schema_name: "event_stream",
  table_name: "history",
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  connection: connection

import_config "#{Mix.env()}.exs"
