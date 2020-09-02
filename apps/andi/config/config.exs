# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :andi, AndiWeb.Endpoint,
  url: [host: "localhost"],
  # You should overwrite this as part of deploying the platform.
  secret_key_base: "z7Iv1RcFiPow+/j3QKYyezhVCleXMuNBmrDO130ddUzysadB1stTt+q0JfIrm/q7",
  render_errors: [view: AndiWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Andi.PubSub, adapter: Phoenix.PubSub.PG2],
  check_origin: ["http://localhost:4000", "https://*.smartcolumbusos.com"],
  http: [stream_handlers: [Web.StreamHandlers.StripServerHeader, :cowboy_stream_h]]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :andi,
  topic: "dataset-registry",
  organization_topic: "organization-raw"

config :andi, :elsa,
  endpoints: [localhost: 9092],
  name: :andi_elsa,
  connection: :andi_reader,
  group_consumer: [
    name: "andi_reader",
    group: "andi_reader_group",
    topics: ["streaming-dead-letters"],
    handler: Andi.MessageHandler,
    handler_init_args: [],
    config: [
      begin_offset: 0,
      offset_reset_policy: :reset_to_earliest,
      prefetch_count: 0,
      prefetch_bytes: 2_097_152
    ]
  ]

config :tesla, adapter: Tesla.Adapter.Hackney

config :andi, ecto_repos: [Andi.Repo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
