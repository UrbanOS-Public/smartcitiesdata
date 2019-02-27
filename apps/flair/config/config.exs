use Mix.Config

# data_topic = "streaming-transformed"
data_topic = "streaming-validated"

config :logger,
  level: :info

config :kafka_ex,
  brokers: [
    {"localhost", 9092}
  ],
  consumer_group: "flair-consumer-group"
