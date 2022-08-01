import Config

config :raptor, RaptorWeb.Endpoint,
  url: [scheme: "https", host: "data.integrationtests.example.com", port: 443],
  http: [protocol_options: [inactivity_timeout: 4_000_000, idle_timeout: 4_000_000]]

config :raptor,
  allowed_origins: ["integrationtests.example.com", "localhost:9001"],
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35]

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :raptor, :brook,
  instance: :raptor,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [Raptor.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]
