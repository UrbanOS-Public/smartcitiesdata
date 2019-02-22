use Mix.Config

config :discovery_api,
  data_lake_url: System.get_env("DATA_LAKE_URL"),
  data_lake_auth_string: System.get_env("DATA_LAKE_AUTH_STRING"),
  thrive_address: System.get_env("HIVE_ADDRESS"),
  thrive_port: String.to_integer(System.get_env("HIVE_PORT")),
  thrive_username: System.get_env("HIVE_USERNAME"),
  thrive_password: System.get_env("HIVE_PASSWORD")

if System.get_env("REDIS_HOST") do
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
