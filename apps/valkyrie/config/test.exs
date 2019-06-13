use Mix.Config

config :valkyrie,
  produce_retries: 1,
  produce_timeout: 100,
  output_topic_prefix: "unit"
