use Mix.Config
import_config "../test/integration/divo_ldap.ex"

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

redix_args = [host: host]
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
  redis: redix_args

config :paddle, Paddle,
  host: host,
  base: "dc=example,dc=org",
  timeout: 3000

config :andi, AndiWeb.Endpoint,
  http: [port: 4000],
  server: true,
  check_origin: false

config :andi, :brook,
  instance: :andi,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "andi-event-stream",
      consumer_config: [
        begin_offset: :earliest,
        offset_reset_policy: :reset_to_earliest
      ]
    ]
  ],
  handlers: [Andi.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "andi:view"]
  ]

config :andi, AndiWeb.Endpoint,
  code_reloader: true,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  reloadable_apps: [:andi],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/andi_web/controllers/.*(ex)$},
      ~r{lib/andi_web/live/.*(ex)$},
      ~r{lib/andi_web/views/.*(ex)$},
      ~r{lib/andi_web/templates/.*(eex)$}
    ]
  ],
  live_view: [
    signing_salt: "SUPER VERY TOP SECRET!!!"
  ]
