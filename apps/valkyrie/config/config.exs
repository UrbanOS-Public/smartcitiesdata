# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

raw_topic = "streaming-raw"
validated_topic = "streaming-validated"

import_config "#{Mix.env()}.exs"
