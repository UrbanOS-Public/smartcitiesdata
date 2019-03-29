use Mix.Config

config :smart_city_registry,
  redis: [
    host: System.get_env("REDIS_HOST")
  ]

config :andi,
  ldap_user: System.get_env("LDAP_USER") |> Andi.LdapUtils.decode_dn!(),
  ldap_pass: System.get_env("LDAP_PASS"),
  ldap_env_ou: System.get_env("LDAP_ENV")

config :paddle, Paddle,
  host: System.get_env("LDAP_HOST"),
  base: System.get_env("LDAP_BASE")
