use Mix.Config

config :estuary,
  topic: "event-stream",
  schema_name: "default",
  table_name: "event_stream",
  topic_reader: Pipeline.Reader.TopicReader,
  table_writer: Pipeline.Writer.TableWriter,
  connection: :estuary_elsa

# Configures the endpoint
config :estuary, EstuaryWeb.Endpoint,
  url: [host: "localhost"],
  # it should be overwriten as part of deploying the platform.
  secret_key_base: "4gV3z+mTeMzrnd+E1lI9xFei/79xYDJ6kN25HlD70cjtspfJ/WIK1mi3sxWIco1v",
  render_errors: [view: EstuaryWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Estuary.PubSub,
  check_origin: ["http://localhost:4000", "https://*.smartcolumbusos.com"]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
