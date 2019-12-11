use Mix.Config

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_table_name: "event_stream"

import_config "#{Mix.env()}.exs"
