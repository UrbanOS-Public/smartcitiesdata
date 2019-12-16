use Mix.Config

config :estuary,
  event_stream_topic: "event-stream",
  event_stream_table_name: "history"

import_config "#{Mix.env()}.exs"
