use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",    #Probably not neccessary
  version: Application.spec(:discovery_api, :vsn)  #Probably not necc

# Do not print debug messages in production
config :logger, level: :info

# Finally import the config/prod.secret.exs
# which should be versioned separately.
