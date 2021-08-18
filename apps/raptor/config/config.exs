# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config


# Configures the endpoint
config :raptor, RaptorWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "EkTifp9BP1V1Mr1QPj9WU05X709LxaHj+2LbqDp6pHjz4XlKPVe/bh9aFq0dxtnx",
  pubsub_server: Raptor.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
