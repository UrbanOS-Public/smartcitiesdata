use Mix.Config
import_config "../test/integration/divo_presto.exs"

host = "localhost"

endpoint = [{to_charlist(host), 9092}]

config :flair,
  window_unit: :second,
  window_length: 1,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats"

config(:flair,
  divo: [
    {DivoKafka, [create_topics: "persisted:1:1,streaming-dead-letters:1:1", outside_host: host]},
    DivoRedis,
    Flair.DivoPresto
  ],
  divo_wait: [dwell: 1000, max_tries: 60]
)

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["persisted"]
  ]

config :prestige,
  base_url: "http://#{host}:8080",
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]

config :kafka_ex,
  brokers: [{host, 9092}]

config :yeet,
  topic: "streaming-dead-letters",
  endpoint: endpoint

config :smart_city_registry,
  redis: [
    host: host
  ]
