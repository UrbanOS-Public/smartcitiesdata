import Config

config :template, TemplateWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "EkTifp9BP1V1Mr1QPj9WU05X709LxaHj+2LbqDp6pHjz4XlKPVe/bh9aFq0dxtnx",
  pubsub_server: Template.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
