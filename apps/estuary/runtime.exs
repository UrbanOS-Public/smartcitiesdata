use Mix.Config

required_envars = [
  "PRESTO_USER",
  "PRESTO_URL",
  "KAFKA_BROKERS",
  "DATA_TOPIC",
  "TABLE_NAME",
  "DLQ_TOPIC"
]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

kafka_brokers = System.get_env("KAFKA_BROKERS")
topic = System.get_env("DATA_TOPIC")
table_name = System.get_env("TABLE_NAME")

endpoints =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {host, String.to_integer(port)} end)

elsa_brokers =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  headers: [user: System.get_env("PRESTO_USER")]

config :estuary,
  elsa_brokers: elsa_brokers,
  event_stream_topic: topic,
  endpoints: endpoints,
  table_name: table_name

config :logger,
  level: :warn

config :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      endpoints: endpoints,
      topic: "streaming-dead-letters"
    ]
  ]

if System.get_env("COMPACTION_SCHEDULE") do
  config :estuary, Estuary.Quantum.Scheduler,
    jobs: [
      compactor: [
        schedule: System.get_env("COMPACTION_SCHEDULE"),
        task: {Estuary.DataWriter, :compact, []},
        timezone: "America/New_York"
      ]
    ]
end
