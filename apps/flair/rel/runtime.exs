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
      topics: [System.get_env("VALIDATED_TOPIC")]
    ]
end

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [
    user: System.get_env("PRESTO_USER"),
    catalog: "hive",
    schema: "default"
  ]
