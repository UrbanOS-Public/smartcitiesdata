import Config

required_envars = [
  "REDIS_HOST",
  "KAFKA_BROKERS",
  "DATA_TOPIC",
  "DLQ_TOPIC"
]

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

config :prestige, :session_opts,
  url: System.get_env("PRESTO_URL"),
  user: System.get_env("PRESTO_USER"),
  catalog: "hive",
  schema: "default"

config :flair,
  window_unit: :minute,
  window_length: 5,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats",
  data_topic: topic,
  elsa_brokers: endpoints,
  message_processing_cadence: 5_000,
  topic_subscriber_config: [
    begin_offset: :earliest,
    offset_reset_policy: :reset_to_earliest,
    max_bytes: 1_000_000,
    min_bytes: 0,
    max_wait_time: 10_000
  ]

config :logger,
  level: :warn
