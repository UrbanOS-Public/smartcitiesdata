use Mix.Config

required_envars = ["REDIS_HOST", "KAFKA_BROKERS", "DATA_TOPIC_PREFIX", "PRESTO_USER", "PRESTO_URL", "OUTPUT_TOPIC"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
topic = System.get_env("DATA_TOPIC_PREFIX")
output_topic = System.get_env("OUTPUT_TOPIC")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {to_charlist(host), String.to_integer(port)} end)

config :kaffe,
  consumer: [
    endpoints: endpoints,
    topics: [],
    consumer_group: "forklift-group",
    message_handler: Forklift.Messages.MessageHandler,
    offset_reset_policy: :reset_to_earliest
  ],
  producer: [
    endpoints: endpoints,
    topics: [output_topic]
  ]

config :yeet,
  topic: "streaming-dead-letters",
  endpoint: endpoints

config :forklift,
  data_topic_prefix: topic,
  output_topic: output_topic

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [user: System.get_env("PRESTO_USER")]

config :redix,
  host: redis_host

config :smart_city_registry,
  redis: [
    host: redis_host
  ]
