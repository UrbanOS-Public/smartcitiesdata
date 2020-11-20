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
  pubsub_server: Andi.PubSub,
  check_origin: ["http://localhost:4000", "https://*.smartcolumbusos.com"],
  http: [stream_handlers: [Web.StreamHandlers.StripServerHeader, :cowboy_stream_h]]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :andi,
  hsts_enabled: true,
  topic: "dataset-registry",
  organization_topic: "organization-raw",
  dead_letter_topic: "streaming-dead-letters",
  documentation_root: ""

config :tesla, adapter: Tesla.Adapter.Hackney

config :andi, ecto_repos: [Andi.Repo]

config :ueberauth, Ueberauth,
  providers: [
    auth0:
      {Ueberauth.Strategy.Auth0,
       [
         default_audience: "andi",
         allowed_request_params: [
           :scope,
           :state,
           :audience,
           :connection,
           :prompt,
           :screen_hint,
           :login_hint,
           :error_message
         ]
       ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
