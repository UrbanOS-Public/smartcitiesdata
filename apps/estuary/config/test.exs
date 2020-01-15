use Mix.Config

config :logger, level: :warn

config :estuary,
  topic_reader: MockReader,
  table_writer: MockTable,
  table_name: "not_the_event_stream",
  instance: :estuary,
  handler: Estuary.MessageHandler,
  connection: :estuary_elsa
