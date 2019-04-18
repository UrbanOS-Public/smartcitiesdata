use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")

if kafka_brokers do
  endpoints =
    kafka_brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn entry -> String.split(entry, ":") end)
    |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

  config :kaffe,
    consumer: [
      endpoints: endpoints,
      topics: [System.get_env("RAW_TOPIC")]
    ],
    producer: [
      endpoints: endpoints,
      topics: [System.get_env("VALIDATED_TOPIC")]
    ]

  config :yeet,
    topic: System.get_env("DLQ_TOPIC"),
    endpoint: endpoints
end

redis_host = System.get_env("REDIS_HOST")

if redis_host do
  config :smart_city_registry,
    redis: [
      host: redis_host
    ]
end
