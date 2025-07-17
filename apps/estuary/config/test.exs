import Config

config :logger, level: :warn

config :estuary,
  init_server: false,
  topic_reader: MockReader,
  table_writer: MockTable,
  table_name: "not_the_event_stream",
  instance: :estuary,
  handler: Estuary.MessageHandler,
  connection: :estuary_elsa,
  prestige: Prestige.Mock,
  event_retrieval_service: EventRetrievalService.Mock,
  message_handler: MessageHandler.Mock,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 30_000
  ]

# By default the server don't run the during test. If one is required,
# the server option can be enabled below.
config :estuary, EstuaryWeb.Endpoint,
  http: [port: 4002],
  server: false,
  live_view: [
    signing_salt: "CHANGEME?"
  ]
