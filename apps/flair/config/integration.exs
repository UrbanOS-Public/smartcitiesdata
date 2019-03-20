use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

System.put_env("HOST", host)

endpoint = [{to_charlist(host), 9092}]

config :flair,
  window_unit: :millisecond,
  window_length: 1

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["validated"]
  ]

config :kafka_ex,
  brokers: [{host, 9092}]

config :flair,
  divo: "./docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]
