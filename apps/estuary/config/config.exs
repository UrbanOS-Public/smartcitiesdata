use Mix.Config

input_topic_prefix = "transformed"

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_table_name: "event_stream",
  data_reader: Pipeline.Reader.DatasetTopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  retry_count: 10,
  retry_initial_delay: 100,
  input_topic_prefix: input_topic_prefix

import_config "#{Mix.env()}.exs"
