use Mix.Config

host = "localhost"
endpoints = [{to_charlist(host), 9092}]
redix_args = [host: host]

config :raptor, RaptorWeb.Endpoint,
  url: [scheme: "https", host: "data.integrationtests.example.com", port: 443],
  http: [protocol_options: [inactivity_timeout: 4_000_000, idle_timeout: 4_000_000]]

config :raptor,
  allowed_origins: ["integrationtests.example.com", "localhost:9001"],
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35],
  hsts_enabled: false

config :redix,
  args: redix_args

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :prestige, :session_opts, url: "http://#{host}:8080"

config :raptor, ecto_repos: [Raptor.Repo]

config :raptor, Raptor.Repo,
  database: "raptor_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: "5456"

config :raptor, Raptor.Auth.TokenHandler,
  issuer: "https://smartcolumbusos-demo.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :raptor, Guardian.DB, repo: Raptor.Repo

config :raptor, :brook,
  instance: :raptor,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoints,
      topic: "event-stream",
      group: "raptor-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Raptor.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "raptor:view"]
  ]

config :raptor,
  user_visualization_limit: 4
