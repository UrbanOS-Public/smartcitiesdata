import Config

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

config :discovery_api,
  dead_letter_topic: "streaming-dead-letters",
  ecto_repos: [DiscoveryApi.Repo]

config :tzdata, :data_dir, "./tzdata"
# Finally import the config/prod.secret.exs
# which should be versioned separately.
