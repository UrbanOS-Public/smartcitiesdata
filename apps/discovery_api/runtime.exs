use Mix.Config

get_redix_args = fn (host, port, password, ssl) ->
  [host: host, port: port, password: password, ssl: ssl]
  |> Enum.filter(fn
    {_, nil} -> false
    {_, ""} -> false
    _ -> true
  end)
end

ssl_enabled = Regex.match?(~r/^true$/i, System.get_env("REDIS_SSL"))
{redis_port, ""} = Integer.parse(System.get_env("REDIS_PORT"))

redix_args = get_redix_args.(System.get_env("REDIS_HOST"), redis_port, System.get_env("REDIS_PASSWORD"), ssl_enabled)

kafka_brokers = System.get_env("KAFKA_BROKERS")

endpoint =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :discovery_api, DiscoveryApiWeb.Endpoint,
  url: [
    scheme: "https",
    host: System.get_env("HOST"),
    port: 443
  ],
  http: [protocol_options: [
    # These values may be superseded by network level timeouts such as a load balancer.
    inactivity_timeout: 4_000_000,
    idle_timeout: 4_000_000
    ]
  ]

config :discovery_api,
  hosted_bucket: System.get_env("HOSTED_FILE_BUCKET"),
  hosted_region: System.get_env("HOSTED_FILE_REGION"),
  presign_key: System.get_env("PRESIGN_KEY")

config :discovery_api, DiscoveryApi.Repo,
  database: System.get_env("POSTGRES_DBNAME"),
  username: System.get_env("POSTGRES_USER"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: System.get_env("POSTGRES_HOST"),
  port: System.get_env("POSTGRES_PORT"),
  ssl: true,
  ssl_opts: [
    versions: [:"tlsv1.2"],
    cacertfile: System.get_env("CA_CERTFILE_PATH")
  ]

postgres_verify_sni = Regex.match?(~r/^true$/i, System.get_env("POSTGRES_VERIFY_SNI"))

if postgres_verify_sni do
  config :discovery_api, DiscoveryApi.Repo,
  ssl_opts: [
    verify: :verify_peer,
    server_name_indication: String.to_charlist(System.get_env("POSTGRES_HOST", "")),
    verify_fun:
    {&:ssl_verify_hostname.verify_fun/3,
     [check_hostname: String.to_charlist(System.get_env("POSTGRES_HOST", ""))]}
  ]
end

required_envars = ["REDIS_HOST", "PRESTO_URL", "ALLOWED_ORIGINS", "PRESIGN_KEY"]

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
  args: redix_args

config :prestige, :session_opts, url: System.get_env("PRESTO_URL")

config :discovery_api, DiscoveryApiWeb.Auth.TokenHandler,
  issuer: System.get_env("AUTH_JWT_ISSUER"),
  allowed_algos: ["RS256"],
  verify_issuer: true

config :discovery_api, Guardian.DB, repo: DiscoveryApi.Repo

config :discovery_api,
  jwks_endpoint: System.get_env("AUTH_JWKS_ENDPOINT"),
  user_info_endpoint: System.get_env("AUTH_USER_INFO_ENDPOINT")

config :ex_aws,
  region: System.get_env("HOSTED_FILE_REGION")

if System.get_env("S3_HOST_NAME") do
  config :ex_aws, :s3,
    scheme: "http://",
    region: "local",
    host: %{
      "local" => System.get_env("S3_HOST_NAME")
    },
    port: System.get_env("S3_PORT") |> String.to_integer()
end

config :discovery_api, :brook,
  instance: :discovery_api,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "discovery-api-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [DiscoveryApi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: redix_args,
      namespace: "discovery-api:view",
      event_limits: %{
        "dataset:update" => 100,
        "data:write:complete" => 100,
        "dataset:query" => 100,
        "organization:update" => 100,
        "user:organization:associate" => 100,
        "user:organization:disassociate" => 100,
        "dataset:delete" => 100,
        "user:login" => 100,
        "dataset:access_group:associate" => 100,
        "dataset:access_group:disassociate" => 100
      }
    ]
  ]

elasticsearch_protocol =
  case System.get_env("ELASTICSEARCH_TLS_ENABLED") do
    "true" -> "https"
    _ -> "http"
  end

config :discovery_api, :elasticsearch,
  url: "#{elasticsearch_protocol}://#{System.get_env("ELASTICSEARCH_HOST")}",
  indices: %{
    datasets: %{
      name: "datasets",
      options: %{
        settings: %{
          number_of_shards: 1
        },
        mappings: %{
          properties: %{
            title: %{
              type: "text",
              index: true
            },
            titleKeyword: %{
              type: "keyword",
              index: true
            },
            modifiedDate: %{
              type: "text",
              index: true
            },
            lastUpdatedDate: %{
              type: "text",
              index: true
            },
            sortDate: %{
              type: "date",
              index: true
            },
            keywords: %{
              type: "text",
              index: true
            },
            organizationDetails: %{
              properties: %{
                id: %{
                  type: "keyword",
                  index: true
                }
              }
            },
            facets: %{
              properties: %{
                orgTitle: %{
                  type: "keyword",
                  index: true
                },
                keywords: %{
                  type: "keyword",
                  index: true
                }
              }
            }
          }
        }
      }
    }
  }

config :telemetry_event,
  metrics_port: System.get_env("METRICS_PORT") |> String.to_integer(),
  add_poller: true,
  add_metrics: [:phoenix_endpoint_stop_duration, :dataset_total_count],
  metrics_options: [
    [
      metric_name: "downloaded_csvs.count",
      tags: [:app, :DatasetId, :Table],
      metric_type: :counter
    ],
    [
      metric_name: "data_queries.count",
      tags: [:app, :DatasetId, :Table, :ContentType],
      metric_type: :counter
    ]
  ]


if System.get_env("RAPTOR_URL") do
  config :discovery_api, raptor_url: System.get_env("RAPTOR_URL")
end
