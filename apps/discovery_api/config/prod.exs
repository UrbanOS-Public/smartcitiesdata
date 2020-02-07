use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  # Probably not neccessary
  root: ".",
  # Probably not necc
  version: Application.spec(:discovery_api, :vsn),
  check_origin: false

# Do not print debug messages in production
config :logger, level: :info

config :redix,
  args: [host: "localhost"]

config :discovery_api, ecto_repos: [DiscoveryApi.Repo]

# Finally import the config/prod.secret.exs
# which should be versioned separately.
