use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :andi, AndiWeb.Endpoint,
  http: [port: 4002],
  server: false,
  live_view: [
    signing_salt: "CHANGEME?"
  ]

# Print only warnings and errors during test
config :logger, level: :warn

config :andi, :brook,
  instance: :andi,
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ],
  handlers: [Andi.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :andi,
  dead_letter_topic: "dead-letters"

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

endpoints = [{host, 9092}]

config :andi, :elsa,
  endpoints: endpoints,
  name: :andi_elsa,
  connection: :andi_reader,
  group_consumer: [
    name: "andi_reader",
    group: "andi_reader_group",
    topics: ["dead-letters"],
    handler: Andi.MessageHandler,
    handler_init_args: [],
    config: [
      begin_offset: 0,
      offset_reset_policy: :latest,
      prefetch_count: 0,
      prefetch_bytes: 2_097_152
    ]
  ]
