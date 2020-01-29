use Mix.Config

config :logger, level: :warn

config :estuary,
  init_server: false,
  topic_reader: MockReader,
  table_writer: MockTable,
  table_name: "not_the_event_stream",
  instance: :estuary,
  handler: Estuary.MessageHandler,
  connection: :estuary_elsa

# By default the server don't run the during test. If one is required,
# the server option can be enabled below.
config :estuary, EstuaryWeb.Endpoint,
  http: [port: 4002],
  server: false,
  live_view: [
    signing_salt: "CHANGEME?"
  ]
