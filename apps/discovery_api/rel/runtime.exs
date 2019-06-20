use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint,
  url: [
    scheme: "https",
    host: System.get_env("HOST"),
    port: 443
  ]

config :discovery_api,
  ldap_user: System.get_env("LDAP_USER"),
  ldap_pass: System.get_env("LDAP_PASS")

required_envars = ["REDIS_HOST", "PRESTO_URL", "ALLOWED_ORIGINS"]

Enum.each(required_envars, fn var ->
  if is_nil(System.get_env(var)) do
    raise ArgumentError, message: "Required environment variable #{var} is undefined"
  end
end)

allowed_origins =
  System.get_env("ALLOWED_ORIGINS")
  |> String.split(",")
  |> Enum.map(&String.trim/1)

config :discovery_api,
  allowed_origins: allowed_origins

config :redix,
  host: System.get_env("REDIS_HOST")

config :smart_city_registry,
  redis: [
    host: System.get_env("REDIS_HOST")
  ]

config :prestige,
  base_url: System.get_env("PRESTO_URL"),
  log_level: :warn

config :paddle, Paddle,
  host: System.get_env("LDAP_HOST"),
  base: System.get_env("LDAP_BASE"),
  account_subdn: System.get_env("LDAP_ACCOUNT_SUBDN")

config :discovery_api, DiscoveryApi.Auth.Guardian, secret_key: System.get_env("GUARDIAN_KEY")
