use Mix.Config

host = "localhost"
endpoints = [{to_charlist(host), 9092}]
redix_args = [host: host]

config :alchemist, AlchemistWeb.Endpoint,
  url: [scheme: "https", host: "data.integrationtests.example.com", port: 443],
  http: [protocol_options: [inactivity_timeout: 4_000_000, idle_timeout: 4_000_000]]

config :alchemist,
  allowed_origins: ["integrationtests.example.com", "localhost:9001"],
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35]

config :redix,
  args: redix_args

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :alchemist, :brook,
  instance: :alchemist,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "alchemist-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Alchemist.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "alchemist:view"]
  ]
