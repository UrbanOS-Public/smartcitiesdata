use Mix.Config

config :alchemist, AlchemistWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "REDACTED",
  pubsub_server: Alchemist.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
