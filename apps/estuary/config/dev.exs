import Config

config :estuary, EstuaryWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_view: [
    signing_salt: "TOP SECRET!!!"
  ]

config :estuary, EstuaryWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/estuary_web/controllers/.*(ex)$},
      ~r{lib/estuary_web/live/.*(ex)$},
      ~r{lib/estuary_web/views/.*(ex)$},
      ~r{lib/estuary_web/templates/.*(eex)$}
    ]
  ]

# Watch static and templates for browser reloading.
# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
