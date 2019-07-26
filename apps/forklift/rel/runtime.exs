use Mix.Config

required_envars = [
  "REDIS_HOST",
  "KAFKA_BROKERS",
  "DATA_TOPIC_PREFIX",
  "PRESTO_USER",
  "PRESTO_URL",
  "OUTPUT_TOPIC"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
topic = System.get_env("DATA_TOPIC_PREFIX")
output_topic = System.get_env("OUTPUT_TOPIC")
metrics_port = System.get_env("METRICS_PORT")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {to_charlist(host), String.to_integer(port)} end)

elsa_brokers =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :kaffe,
  producer: [
    endpoints: endpoints,
    topics: [output_topic]
  ]

config :yeet,
  topic: "streaming-dead-letters",
  endpoint: endpoints

config :forklift,
  elsa_brokers: elsa_brokers,
  brod_brokers: endpoints,
  data_topic_prefix: topic,
  output_topic: output_topic,
  metrics_port: metrics_port,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 500_000,
    max_wait_time: 10_000
  ]

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [user: System.get_env("PRESTO_USER")]

config :redix,
  host: redis_host

config :smart_city_registry,
  redis: [
    host: redis_host
  ]
