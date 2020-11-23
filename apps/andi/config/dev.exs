use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.

host = "localhost"
redix_args = [host: host]

config :andi, AndiWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_view: [
    signing_salt: "TOP SECRET!!!"
  ]

config :andi, AndiWeb.Endpoint,
  pubsub_server: Andi.PubSub,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/andi_web/controllers/.*(ex)$},
      ~r{lib/andi_web/live/.*(ex)$},
      ~r{lib/andi_web/views/.*(ex)$},
      ~r{lib/andi_web/templates/.*(eex)$}
    ]
  ]

config :andi,
  dead_letter_topic: "streaming-dead-letters",
  kafka_endpoints: [{host, 9092}]

# Watch static and templates for browser reloading.
# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
