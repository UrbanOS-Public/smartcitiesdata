use Mix.Config

config :mime, :types, %{
  "application/gtfs+protobuf" => ["gtfs"],
  "application/vnd.ogc.wms_xml" => ["wms"]
}

config :reaper,
  produce_retries: 10,
  produce_timeout: 100

import_config "#{Mix.env()}.exs"
