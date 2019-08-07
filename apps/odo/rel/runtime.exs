use Mix.Config

required_envars = ["REDIS_HOST"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

redis_host = System.get_env("REDIS_HOST")

config :odo,
  working_dir: System.get_env("WORKING_DIR") || "/downloads/",
  secrets_endpoint: System.get_env("SECRETS_ENDPOINT"),
  hosted_file_bucket: System.get_env("HOSTED_FILE_BUCKET") || "hosted-dataset-files"

config :redix,
  host: redis_host

config :ex_aws,
  region: System.get_env("AWS_REGION") || "us-west-2"
