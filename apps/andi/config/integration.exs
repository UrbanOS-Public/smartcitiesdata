use Mix.Config

System.put_env("AUTH0_DOMAIN", "project-hercules.us.auth0.com")
System.put_env("AUTH0_CLIENT_ID", "VHr6xrLKUMsLg1AZYXXLgJBI3LOhcLbY")

host =
  case System.get_env("HOST_IP") do
    nil -> "localhost"
    defined -> defined
  end

redix_args = [host: host]
endpoint = [{host, 9092}]

db_name = "andi_test"
db_username = "postgres"
db_password = "postgres"
db_port = "5456"

bucket_name = "trino-hive-storage"

config :andi,
  divo: "docker-compose.yml",
  divo_wait: [dwell: 700, max_tries: 50],
  kafka_broker: endpoint,
  dead_letter_topic: "dead-letters",
  kafka_endpoints: endpoint,
  hsts_enabled: false,
  access_level: :private,
  hosted_bucket: bucket_name

config :andi, Andi.Repo,
  database: db_name,
  username: db_username,
  password: db_password,
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  port: db_port

config :andi, AndiWeb.Endpoint,
  http: [port: 4000],
  server: true,
  check_origin: false

project_name = Mix.Project.config() |> Keyword.get(:app)

if project_name == :andi do
  config :andi, AndiWeb.Endpoint,
    https: [
      port: 4443,
      otp_app: :andi,
      keyfile: "priv/cert/selfsigned_key.pem",
      certfile: "priv/cert/selfsigned.pem"
    ]
end

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
  handlers: [Andi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "andi:view"]
  ]

config :andi, :auth0,
  url: "https://project-hercules.us.auth0.com/oauth/token",
  audience: "https://project-hercules.us.auth0.com/api/v2/"

config :andi, AndiWeb.Endpoint,
  pubsub_server: Andi.PubSub,
  code_reloader: true,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch",
      "--watch-options-stdin",
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

config :ueberauth, Ueberauth,
  providers: [
    auth0:
      {Ueberauth.Strategy.Auth0,
       [
         default_audience: "andi",
         allowed_request_params: [
           :scope,
           :state,
           :audience,
           :connection,
           :prompt,
           :screen_hint,
           :login_hint,
           :error_message
         ]
       ]}
  ]

config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: "project-hercules.us.auth0.com",
  client_id: "VHr6xrLKUMsLg1AZYXXLgJBI3LOhcLbY",
  client_secret: System.get_env("AUTH0_CLIENT_SECRET")

config :andi, AndiWeb.Auth.TokenHandler,
  issuer: "https://project-hercules.us.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :andi, Guardian.DB, repo: Andi.Repo

config :ex_aws,
  debug_requests: true,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000

System.put_env("AWS_ACCESS_KEY_ID", "minioadmin")
System.put_env("AWS_ACCESS_KEY_SECRET", "minioadmin")
System.put_env("ANDI_LOGO_URL", "/images/UrbanOS.svg")
System.put_env("ANDI_HEADER_TEXT", "Data Submission Tool")
