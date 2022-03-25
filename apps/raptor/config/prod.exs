use Mix.Config

config :raptor, RaptorWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Do not print debug messages in production
config :logger, level: :info

config :tzdata, :data_dir, "./tzdata"
