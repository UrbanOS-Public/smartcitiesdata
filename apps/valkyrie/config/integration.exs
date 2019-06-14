use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

endpoint = [{to_charlist(host), 9092}]

config :logger,
  level: :info

config :valkyrie,
  elsa_brokers: [{String.to_atom(host), 9092}],
  brod_brokers: endpoint,
  input_topic_prefix: "raw",
  output_topic_prefix: "validated",
  divo: [
    {DivoKafka, [create_topics: "raw:1:1,validated:1:1,dead-letters:1:1", outside_host: host, auto_topic: false]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50]

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["validated"],
    partition_strategy: :md5
  ]

config :yeet,
  topic: "dead-letters",
  endpoint: endpoint

config :smart_city_registry,
  redis: [
    host: host
  ]
