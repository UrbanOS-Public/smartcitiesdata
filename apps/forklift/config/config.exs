# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :forklift,
  topics: %{
    registry: "registry-topic",
    raw_data: "raw-data-topic"
  }

# config :prestige, base_url: "https://presto.dev.internal.smartcolumbusos.com"
config :prestige, base_url: "http://localhost:8080"

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: ["data-topic"],
    consumer_group: "forklift-group-1",
    message_handler: Forklift.MessageProcessor,
    # offset_reset_policy: :reset_to_latest,
    # max_bytes: 500_000,
    worker_allocation_strategy: :worker_per_topic_partition
  ]

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :forklift, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:forklift, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
