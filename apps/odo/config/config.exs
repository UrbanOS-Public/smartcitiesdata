use Mix.Config

config :odo,
  collector: StreamingMetrics.PrometheusMetricCollector

config :mime, :types, %{
  "application/gtfs+protobuf" => ["gtfs"],
  "application/vnd.ogc.wms_xml" => ["wms"]
}

import_config "#{Mix.env()}.exs"
