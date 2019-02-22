# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

raw_topic = "streaming-raw"
validated_topic = "streaming-validated"

endpoints = [localhost: 9092]

config :valkyrie,
  env: Mix.env()

config :kaffe,
  consumer: [
    endpoints: endpoints,
    topics: [raw_topic],
    consumer_group: "valkyrie-group",
    message_handler: Valkyrie.MessageHandler,
    offset_reset_policy: :reset_earliest,
    start_with_earliest_message: true,
    worker_allocation_strategy: :worker_per_topic_partition
  ],
  producer: [
    endpoints: endpoints,
    topics: [validated_topic]
  ]

import_config "#{Mix.env()}.exs"
