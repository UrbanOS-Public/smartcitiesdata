use Mix.Config

config :estuary,
  topic: "event-stream",
  schema_name: "event_stream",
  table_name: "history",
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  connection: :estuary_elsa

import_config "#{Mix.env()}.exs"
