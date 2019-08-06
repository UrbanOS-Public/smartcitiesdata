use Mix.Config

required_envars = ["REDIS_HOST"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

redis_host = System.get_env("REDIS_HOST")

config :odo,
  working_dir: System.get_env("WORKING_DIR") || "/downloads/"

config :redix,
  host: redis_host

config :smart_city_registry,
  redis: [
    host: redis_host
  ]
