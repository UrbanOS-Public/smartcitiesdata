use Mix.Config

config :discovery_api, DiscoveryApiWeb.Endpoint, url: [host: System.get_env("HOST"), port: System.get_env("PORT")]

config :discovery_api,
  ldap_user: System.get_env("LDAP_USER"),
  ldap_pass: System.get_env("LDAP_PASS")

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

config :paddle, Paddle,
  host: System.get_env("LDAP_HOST"),
  base: System.get_env("LDAP_BASE"),
  account_subdn: "cn=users,cn=accounts"

config :discovery_api, DiscoveryApi.Auth.Guardian, secret_key: System.get_env("GUARDIAN_KEY")
