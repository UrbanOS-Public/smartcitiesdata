use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint,
  http: [port: 4001],
  server: false,
  url: [host: "data.tests.example.com", port: 80]

config :discovery_api,
  test_mode: true

config :logger, level: :warn

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :paddle, Paddle, base: "dc=example,dc=org"
