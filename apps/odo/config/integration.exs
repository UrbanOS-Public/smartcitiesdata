use Mix.Config
# We should turn this into a repo to share with Reaper
import_config "../test/integration/divo_minio.ex"

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

config :logger,
  level: :info

bucket_name = "hosted-dataset-files"

config :odo,
  divo: [
    DivoRedis,
    {Reaper.DivoMinio, [bucket_name: bucket_name]}
  ],
  divo_wait: [dwell: 1000, max_tries: 120],
  hosted_file_bucket: bucket_name

config :smart_city_registry,
  redis: [
    host: host
  ]

config :redix,
  host: host

config :ex_aws,
  debug_requests: true,
  access_key_id: "access_key_testing",
  secret_access_key: "secret_key_testing",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000
