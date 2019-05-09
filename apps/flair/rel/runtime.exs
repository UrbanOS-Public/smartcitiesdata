use Mix.Config

required_envars = ["REDIS_HOST", "KAFKA_BROKERS", "DATA_TOPIC", "DLQ_TOPIC"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
dlq_topic = System.get_env("DLQ_TOPIC")
topic = System.get_env("DATA_TOPIC")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {host, String.to_integer(port)} end)

# yeet requires atom or charlist hosts, while kafka_ex expects strings
yeet_endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :kafka_ex,
  brokers: endpoints

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [
    user: System.get_env("PRESTO_USER"),
    catalog: "hive",
    schema: "default"
  ]

config :flair,
  window_unit: :minute,
  window_length: 5,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats",
  data_topic: topic

config :logger,
  level: :warn

config :smart_city_registry,
  redis: [
    host: redis_host
  ]

config :yeet,
  endpoint: yeet_endpoints,
  topic: dlq_topic
