use Mix.Config

config :valkyrie,
  elsa_brokers: [localhost: 9092],
  retry_count: 5,
  retry_initial_delay: 10,
  input_topic_prefix: "raw",
  output_topic_prefix: "unit",
  broadway_producer_module: Fake.Producer
