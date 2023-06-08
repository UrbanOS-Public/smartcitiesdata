use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :discovery_api, DiscoveryApiWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :prestige, :session_opts, url: "http://localhost:8080"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :mix_test_watch,
  clear: true

config :redix,
  args: [host: "localhost"]

config :discovery_api,
  dead_letter_topic: "streaming-dead-letters",
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 1000, max_tries: 20]
