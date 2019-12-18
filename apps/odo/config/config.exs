use Mix.Config

config :odo,
  collector: StreamingMetrics.PrometheusMetricCollector

import_config "#{Mix.env()}.exs"
