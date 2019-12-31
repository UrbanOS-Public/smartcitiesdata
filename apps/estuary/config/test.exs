use Mix.Config

config :logger, level: :warn

config :estuary,
  topic_reader: MockReader,
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

# config :prestige,
# base_url: "http://127.0.0.1:8080",
# headers: [
#   user: "estuary",
#   catalog: "hive",
#   schema: "event_stream"
# ]
