use Mix.Config

config :logger, level: :warn

config :estuary,
  topic_reader: MockReader,
  table_writer: MockTable,
  endpoints: nil,
  instance: :estuary,
  handler: Estuary.MessageHandler,
  connection: :estuary_elsa

config :estuary, :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Test,
    init_args: []
  ]
