use Mix.Config

@conection :estuary_elsa

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_table_name: "event_stream",
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  retry_count: 10,
  retry_initial_delay: 100,
  conection: @conection

import_config "#{Mix.env()}.exs"
