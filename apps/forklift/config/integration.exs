use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{to_charlist(host), 9094}]

config :forklift,
  message_processing_cadence: 5_000,
  data_topic_prefix: "integration"

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: [],
    max_retries: 30,
    retry_backoff_ms: 500
  ],
  consumer: [
    min_bytes: 0,
    endpoints: endpoint
  ]

config :yeet,
  endpoint: endpoint

config :prestige,
  base_url: "http://#{host}:8080",
  headers: [
    catalog: "hive",
    schema: "default",
    user: "foobar"
  ]

config(:forklift, divo: "docker-compose.yml", divo_wait: [dwell: 1000, max_tries: 50])

config :redix,
  host: host

config :smart_city_registry,
  redis: [
    host: host
  ]
