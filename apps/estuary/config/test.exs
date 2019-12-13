use Mix.Config

config :estuary,
  elsa_endpoint: nil

config :logger, level: :warn

config :estuary,
  data_reader: MockReader,
  topic_writer: MockTopic,
  table_writer: MockTable
