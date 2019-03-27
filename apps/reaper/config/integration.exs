use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{to_charlist(host), 9092}]

System.put_env("HOST", host)

webserver_host = host
webserver_port = 7000

config :logger,
  level: :info

config :reaper,
  divo: "./docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]

config :smart_city_registry,
  redis: [
    host: host
  ]

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["streaming-raw"],
    partition_strategy: :md5
  ]

config :redix,
  host: host
