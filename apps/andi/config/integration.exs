use Mix.Config
import_config "../test/integration/divo_ldap.ex"

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

endpoint = [{host, 9092}]

config :andi,
  divo: [
    {DivoKafka, [create_topics: "event-stream:1:1", outside_host: host]},
    {DivoRedis, []},
    Andi.DivoLdap
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  ldap_user: [cn: "admin"],
  ldap_pass: "admin",
  ldap_env_ou: "integration",
  kafka_broker: endpoint

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

config :brook, :config,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "andi-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Andi.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: [host: host], namespace: "andi:view"]
  ]
