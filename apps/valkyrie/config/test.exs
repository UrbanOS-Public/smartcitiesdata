use Mix.Config

config :valkyrie,
  produce_retries: 1,
  produce_timeout: 100,
  input_topic_prefix: "raw",
  output_topic_prefix: "unit"
