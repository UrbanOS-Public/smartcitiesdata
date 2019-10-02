use Mix.Config

config :pipeline,
  elsa_brokers: [{:localhost, 9092}],
  output_topic: "output-topic",
  producer_name: :"integration-producer",
  divo: [{DivoKafka, [outside_host: "localhost"]}],
  divo_wait: [dwell: 700, max_tries: 50]
