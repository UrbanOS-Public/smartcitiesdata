use Mix.Config
import_config "../test/integration/divo_sftp.ex"

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
  divo: "./test/integration/docker-compose.yaml"
    #   {DivoKafka, [create_topics: "streaming-raw:1:1,streaming-dead-letters:1:1", outside_host: host]},
    #   DivoRedis,
    #   Reaper.DivoSftp,
  divo_wait: [dwell: 700, max_tries: 50]

config :smart_city_registry,
  redis: [
    host: host
  ]

config :kaffe,
  producer: [
    endpoints: endpoint,
    topics: ["streaming-raw", "streaming-dead-letters"],
    partition_strategy: :md5
  ]

config :redix,
  host: host

config :yeet,
  endpoint: endpoint,
  topic: "streaming-dead-letters"
