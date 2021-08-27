use Mix.Config

config :template, TemplateWeb.Endpoint,
  url: [scheme: "https", host: "data.integrationtests.example.com", port: 443],
  http: [protocol_options: [inactivity_timeout: 4_000_000, idle_timeout: 4_000_000]]

config :template,
  allowed_origins: ["integrationtests.example.com", "localhost:9001"],
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35]

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :template, :brook,
  instance: :template,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [Template.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]
