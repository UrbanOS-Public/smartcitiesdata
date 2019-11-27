use Mix.Config

config :estuary,
  elsa_endpoint: [localhost: 9092],
  event_stream_topic: "event-stream"

import_config "#{Mix.env()}.exs"
