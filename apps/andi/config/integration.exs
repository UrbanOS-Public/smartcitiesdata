use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

System.put_env("HOST", host)

config :andi,
  divo: "./docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50],
  ldap_user: [cn: "admin"],
  ldap_pass: "admin",
  ldap_env_ou: "integration"

config :smart_city_registry,
  redis: [host: host]

config :paddle, Paddle,
  host: host,
  base: "dc=example,dc=org",
  timeout: 3000

config :andi, AndiWeb.Endpoint,
  http: [port: 4000],
  server: true,
  check_origin: false
