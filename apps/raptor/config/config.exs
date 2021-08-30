use Mix.Config

config :raptor, RaptorWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "EkTifp9BP1V1Mr1QPj9WU05X709LxaHj+2LbqDp6pHjz4XlKPVe/bh9aFq0dxtnx",
  pubsub_server: Raptor.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    auth0:
      {Ueberauth.Strategy.Auth0,
       [
         default_audience: "raptor",
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

import_config "#{Mix.env()}.exs"
