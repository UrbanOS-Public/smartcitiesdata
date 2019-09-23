# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

input_topic_prefix = "transformed"

config :forklift,
  retry_count: 10,
  retry_initial_delay: 100,
  cache_processing_batch_size: 1_000,
  message_processing_cadence: 10_000,
  number_of_empty_reads_to_delete: 50,
  input_topic_prefix: input_topic_prefix,
  collector: StreamingMetrics.PrometheusMetricCollector

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_level: :debug

import_config "#{Mix.env()}.exs"

config :prestige,
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]
