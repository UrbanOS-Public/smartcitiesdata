use Mix.Config

config :discovery_streams, DiscoveryStreamsWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  server: true,
  root: ".",
  version: Application.spec(:discovery_streams, :vsn),
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :discovery_streams, DiscoveryStreamsWeb.Endpoint, check_origin: false

config :discovery_streams, :raptor,
  url: "http://raptor/api/authorize"

config :logger,
  level: :info

config :ex_aws,
  debug_requests: false
