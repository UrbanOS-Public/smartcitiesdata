use Mix.Config

host = "127.0.0.1"
endpoints = [{String.to_atom(host), 9092}]

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  http: [port: 4001],
  server: false

config :discovery_streams,
  raptor_url: "raptor.url"

config :discovery_streams, endpoints: [localhost: 9092]

config :discovery_streams, :brook,
  instance: :discovery_streams,
  handlers: [DiscoveryStreams.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ]
