use Mix.Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
# config :andi, AndiWeb.Endpoint,
#   http: [:inet6, port: System.get_env("PORT") || 4000],
#   # url: [host: "example.com", port: 80],
#   # cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger,
  level: :info

config :andi, AndiWeb.Endpoint,
  pubsub_server: Andi.PubSub,
  http: [port: {:system, "PORT"}],
  server: true,
  root: ".",
  cache_static_manifest: "priv/static/cache_manifest.json",
  version: Application.spec(:andi, :vsn),
  live_view: [
    signing_salt: "CHANGE BEFORE PROD"
  ]

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

config :andi,
  dead_letter_topic: "streaming-dead-letters",
  kafka_endpoints: [{host, 9092}]

config :tzdata, :data_dir, "./tzdata"
