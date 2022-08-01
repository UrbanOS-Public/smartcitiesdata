import Config

config :flair,
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter

config :logger,
  level: :info

config :prestige, :session_opts,
  user: "presto",
  catalog: "hive",
  schema: "default"

import_config "#{Mix.env()}.exs"
