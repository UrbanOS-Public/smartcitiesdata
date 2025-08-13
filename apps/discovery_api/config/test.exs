import Config

System.put_env("AWS_ACCESS_KEY_ID", "minioadmin")
System.put_env("AWS_ACCESS_KEY_SECRET", "minioadmin")
config :prestige, :session_opts, url: "http://localhost:8080"
host = "localhost"

config :discovery_api, DiscoveryApiWeb.Endpoint,
  http: [port: 4001],
  server: false,
  url: [scheme: "https", host: "data.tests.example.com", port: 443]

config :discovery_api,
  dead_letter_topic: "dead-letters",
  user_info_endpoint: "pretend-this-is-a-url/userinfo",
  jwks_endpoint: "pretend-this-is-a-url/jwks",
  allowed_origins: ["tests.example.com"],
  test_mode: true,
  hsts_enabled: false,
  persistence: PersistenceMock,
  raptor_service: RaptorServiceMock,
  redix_module: RedixMock,
  presto_service: PrestoServiceMock,
  model: ModelMock,
  model_access_utils: ModelAccessUtilsMock,
  prestige: PrestigeMock,
  prestige_result: PrestigeResultMock,
  mapper: MapperMock,
  metrics_service: MetricsServiceMock

config :logger, level: :warn

config :discovery_api,
  raptor_url: "raptor.url"

config :ex_json_schema,
       :remote_schema_resolver,
       fn url -> URLResolver.resolve_url(url) end

config :discovery_api, :brook,
  instance: :discovery_api,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [DiscoveryApi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :discovery_api,
  user_visualization_limit: 4

config :discovery_api, DiscoveryApiWeb.Auth.TokenHandler,
  issuer: "https://urbanos-dev.us.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :discovery_api, ecto_repos: [DiscoveryApi.Repo]
config :discovery_api, Guardian.DB, repo: DiscoveryApi.Repo

config :discovery_api, :elasticsearch,
  url: "http://#{host}:9200",
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
