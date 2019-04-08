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
  window_length: 1

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
