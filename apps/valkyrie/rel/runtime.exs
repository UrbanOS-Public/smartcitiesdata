use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")
input_topic_prefix = System.get_env("DATA_TOPIC_PREFIX")
output_topic_prefix = System.get_env("OUTPUT_TOPIC_PREFIX")

config :logger,
  level: :warn

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  elsa_brokers =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  config :yeet,
    topic: System.get_env("DLQ_TOPIC"),
    endpoint: endpoints

  config :valkyrie,
    elsa_brokers: elsa_brokers,
    topic_subscriber_config: [
      begin_offset: :earliest,
      offset_reset_policy: :reset_to_earliest,
      max_bytes: 1_000_000,
      min_bytes: 500_000,
      max_wait_time: 10_000
    ]
end

config :valkyrie,
  input_topic_prefix: input_topic_prefix,
  output_topic_prefix: output_topic_prefix

redis_host = System.get_env("REDIS_HOST")

if redis_host do
  config :smart_city_registry,
    redis: [
      host: redis_host
    ]
end
