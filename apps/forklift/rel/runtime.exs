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
      topics: [System.get_env("DATA_TOPIC"), System.get_env("REGISTRY_TOPIC")],
      consumer_group: "forklift-group",
      message_handler: Forklift.MessageProcessor,
      offset_reset_policy: :reset_to_earliest
    ]
end

config :forklift,
  data_topic: System.get_env("DATA_TOPIC"),
  registry_topic: System.get_env("REGISTRY_TOPIC"),
  user: "forklift"


config :prestige, base_url: System.get_env("PRESTO_URL")
