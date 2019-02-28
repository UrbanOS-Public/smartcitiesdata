use Mix.Config

if(System.get_env("REDIS_HOST")) do
  config :redix,
    host: System.get_env("REDIS_HOST")
end

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
      topics: [System.get_env("KAFKA_TOPIC") || "dataset-registry"],
      consumer_group: System.get_env("KAFKA_CONSUMER_GROUP") || "discovery-dataset-consumer",
      message_handler: DiscoveryApi.Data.DatasetEventListener,
      rebalance_delay_ms: 10_000,
      start_with_earliest_message: true
    ]
end
