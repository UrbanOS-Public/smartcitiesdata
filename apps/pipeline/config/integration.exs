use Mix.Config

config :pipeline,
  elsa_brokers: [{:localhost, 9092}],
  input_topic_prefix: "input-prefix",
  retry_count: 10,
  retry_initial_delay: 10,
  divo: [{DivoKafka, [outside_host: "localhost"]}],
  divo_wait: [dwell: 700, max_tries: 50]
