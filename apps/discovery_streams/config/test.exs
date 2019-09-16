use Mix.Config

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  http: [port: 4001],
  server: false

config :kaffe,
  consumer: [
    topics: ["shuttle-position", "cota-vehicle-positions"]
  ]

config :discovery_streams, :brook,
  handlers: [DiscoveryStreams.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]
