use Mix.Config
import_config "../test/integration/divo_sftp.ex"

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

endpoint = [{String.to_atom(host), 9092}]

System.put_env("HOST", host)

webserver_host = host
webserver_port = 7000

config :logger,
  level: :info

config :reaper,
  divo: [
    {DivoKafka, [create_topics: "streaming-dead-letters:1:1", outside_host: host]},
    DivoRedis,
    Reaper.DivoSftp
  ],
  divo_wait: [dwell: 1000, max_tries: 120],
  elsa_brokers: endpoint,
  output_topic_prefix: "raw"

config :smart_city_registry,
  redis: [
    host: host
  ]

config :redix,
  host: host

config :yeet,
  endpoint: endpoint,
  topic: "streaming-dead-letters"
