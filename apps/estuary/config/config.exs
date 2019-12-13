use Mix.Config

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_table_name: "event_stream",
  data_reader: Pipeline.Reader.DatasetTopicReader,
  topic_writer: Pipeline.Writer.TopicWriter,
  table_writer: Pipeline.Writer.TableWriter

import_config "#{Mix.env()}.exs"
