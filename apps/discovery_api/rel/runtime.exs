use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint, url: [host: System.get_env("HOST"), port: System.get_env("PORT")]

required_envars = ["REDIS_HOST", "PRESTO_URL"]
Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

config :redix,
  host: System.get_env("REDIS_HOST")

config :smart_city_registry,
  redis: [
    host: System.get_env("REDIS_HOST")
  ]

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  log_level: :warn
