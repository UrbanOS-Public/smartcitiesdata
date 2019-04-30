use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

System.put_env("HOST", host)

endpoint = [{to_charlist(host), 9094}]

config :flair,
  window_unit: :millisecond,
  window_length: 1,
  message_timeout: 5 * 60 * 1_000,
  task_timeout: 5 * 60 * 1_000,
  table_name_timing: "operational_stats",
  table_name_quality: "dataset_quality"

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["streaming-transformed"]
  ]

config :prestige,
  base_url: "http://#{host}:8080",
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]

config :kafka_ex,
  brokers: [{host, 9094}]

config :flair,
  divo: "./docker-compose.yaml",
  divo_wait: [dwell: 1000, max_tries: 60]

config :yeet,
  topic: "streaming-dead-letters",
  endpoint: endpoint

config :redix,
  host: host

config :smart_city_registry,
  redis: [
    host: host
  ]
