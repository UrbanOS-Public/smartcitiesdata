# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :alchemist,
  retry_count: 10,
  retry_initial_delay: 100,
  max_outgoing_bytes: 900_000,
  input_topic_prefix: "raw",
  output_topic_prefix: "transformed",
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 10_000_000,
    min_bytes: 0,
    max_wait_time: 10_000,
    prefetch_count: 0,
    prefetch_bytes: 100_000_000
  ]

import_config "#{Mix.env()}.exs"
