import Config

config :pipeline,
  elsa_brokers: [{:localhost, 9092}],
  output_topic: "output-topic",
  producer_name: :"integration-producer",
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1_000, max_tries: 120]

config :prestige, :session_opts,
  url: "http://localhost:8080",
  catalog: "hive",
  schema: "default",
  user: "foobar"

config :ex_aws,
  debug_requests: true,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000
