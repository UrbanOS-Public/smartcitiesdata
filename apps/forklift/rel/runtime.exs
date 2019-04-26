use Mix.Config

required_envars = ["REDIS_HOST", "KAFKA_BROKERS", "DATA_TOPIC", "PRESTO_USER", "PRESTO_URL"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
topic = System.get_env("DATA_TOPIC")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :kaffe,
  consumer: [
    endpoints: endpoints,
    topics: [topic],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_earliest
  ]

config :yeet,
  topic: "streaming-dead-letters",
  endpoint: endpoints

config :forklift,
  data_topic: topic

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [user: System.get_env("PRESTO_USER")]

config :redix,
  host: redis_host

config :smart_city_registry,
  redis: [
    host: redis_host
  ]

config :exq,
  name: Exq,
  host: redis_host,
  port: 6379,
  namespace: "forklift:exq",
  concurrency: 30,
  queues: ["default"],
  poll_timeout: 50,
  scheduler_poll_timeout: 200,
  scheduler_enable: true,
  max_retries: 25,
  shutdown_timeout: 500,
  node_identifier: Forklift.NodeIdentifier,
  start_on_application: false
