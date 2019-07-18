use Mix.Config

config :valkyrie,
  elsa_brokers: [localhost: 9092],
  produce_retries: 5,
  produce_timeout: 10,
  input_topic_prefix: "raw",
  output_topic_prefix: "unit",
  broadway_producer_module: Fake.Producer
