use Mix.Config

config :logger, level: :warn

config :estuary,
  topic_reader: MockReader,
  table_writer: MockTable,
  instance: :estuary,
  handler: Estuary.MessageHandler,
  connection: :estuary_elsa
