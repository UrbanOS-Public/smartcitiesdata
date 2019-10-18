use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint,
  http: [port: 4001],
  server: false,
  url: [host: "data.tests.example.com", port: 80]

config :discovery_api,
  allowed_origins: ["tests.example.com"],
  test_mode: true

config :discovery_api,
  jwks_endpoint: "pretend-this-is-a-url/jwks",
  user_info_endpoint: "pretend-this-is-a-url/userinfo"

config :logger, level: :warn

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :paddle, Paddle, base: "dc=example,dc=org"

config :discovery_api, DiscoveryApi.Auth.Auth0.Guardian, issuer: "https://smartcolumbusos-demo.auth0.com/"

config :discovery_api, :brook,
  instance: :discovery_api,
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ],
  handlers: [DiscoveryApi.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]
