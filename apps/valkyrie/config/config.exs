# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :valkyrie,
  produce_retries: 10,
  produce_timeout: 100,
  max_outgoing_bytes: 900_000,
  old_output_topic: "validated",
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 0,
    max_wait_time: 10_000
  ]

import_config "#{Mix.env()}.exs"
