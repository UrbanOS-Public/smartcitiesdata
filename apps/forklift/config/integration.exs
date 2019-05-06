use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{to_charlist(host), 9094}]

config :forklift,
  message_processing_cadence: 5_000

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["streaming-persisted"],
    max_retries: 30,
    retry_backoff_ms: 500
  ],
  consumer: [
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

config :exq,
  name: Exq,
  host: host,
  port: 6379,
  namespace: "forklift:exq",
  concurrency: :infinite,
  queues: ["default"],
  poll_timeout: 50,
  scheduler_poll_timeout: 200,
  scheduler_enable: true,
  max_retries: 25,
  shutdown_timeout: 500,
  start_on_application: false
