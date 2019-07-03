use Mix.Config

host = "localhost"
endpoints = [{to_charlist(host), 9092}]

config :discovery_api, DiscoveryApiWeb.Endpoint, url: [host: "data.integrationtests.example.com", port: 80]

config :discovery_api,
  allowed_origins: ["integrationtests.example.com"],
  divo: "test/integration/docker-compose.yaml",
  divo_wait: [dwell: 2000, max_tries: 35],
  ldap_user: [cn: "admin"],
  ldap_pass: "admin",
  hosted_bucket: "kdp-cloud-storage"

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

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  region: "us-east-1",
  port: 9000

System.put_env("AWS_ACCESS_KEY_ID", "testing_access_key")
System.put_env("AWS_SECRET_ACCESS_KEY", "testing_secret_key")
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
