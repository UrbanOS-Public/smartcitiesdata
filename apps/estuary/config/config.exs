use Mix.Config

<<<<<<< HEAD
<<<<<<< HEAD
connection = :estuary_elsa
=======
input_topic_prefix = "transformed"
>>>>>>> adding config for event reading
=======
connection = :estuary_elsa
>>>>>>> Adding dead letter

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_table_name: "event_stream",
<<<<<<< HEAD
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  retry_count: 10,
  retry_initial_delay: 100,
  connection: connection
<<<<<<< HEAD
=======
  data_reader: Pipeline.Reader.DatasetTopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  retry_count: 10,
  retry_initial_delay: 100,
  input_topic_prefix: input_topic_prefix
>>>>>>> adding config for event reading
=======
>>>>>>> Adding dead letter

import_config "#{Mix.env()}.exs"
