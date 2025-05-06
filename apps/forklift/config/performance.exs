import Config

local_bucket = "trino-hive-storage"
local_presto = "http://localhost:8080"
presto_bucket = System.get_env("S3_WRITER_BUCKET") || local_bucket
presto_url = System.get_env("PRESTO_URL") || local_presto

config :forklift,
  data_reader: MockReader,
  topic_writer: MockTopic,
  table_writer: Pipeline.Writer.S3Writer,
  s3_writer_bucket: presto_bucket,
  retry_count: 100,
  retry_initial_delay: 100,
  retry_max_wait: 1_000 * 60 * 60,
  profiling_enabled: false

config :forklift, :brook,
  instance: :forklift,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [Forklift.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: [
      namespace: "forklift:view"
    ]
  ]

config :logger,
  level: :debug

config :prestige, :session_opts,
  url: presto_url,
  user: "forklift-performance",
  catalog: "hive",
  schema: "default"

config :redix, args: nil

config :ex_aws,
  debug_requests: false,
  region: System.get_env("AWS_REGION") || "us-west-2"

if presto_bucket == local_bucket do
  config :forklift,
    divo: "docker-compose.yml",
    divo_wait: [dwell: 1000, max_tries: 120]

  config :ex_aws,
    access_key_id: "minioadmin",
    secret_access_key: "minioadmin",
    awscli_auth_adapter: ExAws.STS.AuthCache.AssumeRoleCredentialsAdapter

  config :ex_aws, :s3,
    scheme: "http://",
    region: "local",
    host: %{
      "local" => "localhost"
    },
    port: 9000
end
