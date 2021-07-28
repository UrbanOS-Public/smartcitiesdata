use Mix.Config

System.put_env("AWS_ACCESS_KEY_ID", "testing_access_key")
System.put_env("AWS_ACCESS_KEY_SECRET", "testing_secret_key")
config :prestige, :session_opts, url: "http://localhost:8080"

config :discovery_api, DiscoveryApiWeb.Endpoint,
  http: [port: 4001],
  server: false,
  url: [scheme: "https", host: "data.tests.example.com", port: 443]

config :discovery_api,
  user_info_endpoint: "pretend-this-is-a-url/userinfo",
  jwks_endpoint: "pretend-this-is-a-url/jwks",
  allowed_origins: ["tests.example.com"],
  test_mode: true,
  hsts_enabled: false

config :logger, level: :warn

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :discovery_api, :brook,
  instance: :discovery_api,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [DiscoveryApi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :discovery_api,
  user_visualization_limit: 4

config :discovery_api, DiscoveryApiWeb.Auth.TokenHandler,
  issuer: "https://smartcolumbusos-demo.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :discovery_api, ecto_repos: [DiscoveryApi.Repo]
config :discovery_api, Guardian.DB, repo: DiscoveryApi.Repo
