use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

System.put_env("HOST", host)

endpoints = [{to_charlist(host), 9092}]

config :discovery_api, DiscoveryApiWeb.Endpoint, url: [host: "data.integrationtests.example.com", port: 80]

config :discovery_api,
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35],
  ldap_user: [cn: "admin"],
  ldap_pass: "admin"

config :smart_city_registry,
  redis: [
    host: host
  ]

config :redix,
  host: host

config :phoenix,
  serve_endpoints: true,
  persistent: true

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :prestige,
  base_url: "http://#{host}:8080"

config :paddle, Paddle,
  host: host,
  base: "dc=example,dc=org",
  timeout: 3000
