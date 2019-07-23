use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

config :logger,
  level: :info

config :valkyrie,
  elsa_brokers: [{String.to_atom(host), 9092}],
  input_topic_prefix: "raw",
  output_topic_prefix: "validated",
  divo: [
    {DivoKafka, [create_topics: "raw:1:1,validated:1:1,dead-letters:1:1", outside_host: host, auto_topic: false]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  retry_count: 5,
  retry_initial_delay: 1500

config :yeet,
  topic: "dead-letters",
  endpoint: [{to_charlist(host), 9092}]

config :smart_city_registry,
  redis: [
    host: host
  ]
