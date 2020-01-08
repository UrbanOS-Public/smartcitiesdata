use Mix.Config

config :logger, level: :warn

config :estuary,
  topic_reader: MockReader,
  topic_writer: MockTopic,
  table_writer: MockTable,
  endpoints: [localhost: 9092],
  instance: :estuary,
  handler: Estuary.MessageHandler,
  connection: :estuary_elsa

config :estuary, :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Test,
    init_args: []
  ]
