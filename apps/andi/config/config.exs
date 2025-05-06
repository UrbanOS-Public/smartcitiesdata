# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :andi, AndiWeb.Endpoint,
  url: [host: "localhost"],
  # You should overwrite this as part of deploying the platform.
  secret_key_base: "z7Iv1RcFiPow+/j3QKYyezhVCleXMuNBmrDO130ddUzysadB1stTt+q0JfIrm/q7",
  render_errors: [view: AndiWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Andi.PubSub,
  check_origin: ["http://localhost:4000", "https://*.urbanos-demo.com"],
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
  documentation_root: "",
  vault_role: "andi-role",
  dataset_name_max_length: 75,
  org_name_max_length: 40

config :tesla, adapter: Tesla.Adapter.Hackney, recv_timeout: 120_000

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
import_config "#{config_env()}.exs"
