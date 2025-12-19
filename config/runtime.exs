import Config

# Runtime configuration for production environment
# This file is evaluated at runtime when the release starts,
# allowing for environment-based configuration without rebuilding.

if config_env() == :prod do
  # =============================================================================
  # Kafka Configuration
  # =============================================================================

  kafka_brokers =
    System.get_env("KAFKA_BROKERS", "localhost:9092")
    |> String.split(",")
    |> Enum.map(fn broker ->
      [host, port] = String.split(broker, ":")
      {host, String.to_integer(port)}
    end)

  event_stream_topic = System.get_env("EVENT_STREAM_TOPIC", "event-stream")
  dead_letter_topic = System.get_env("DEAD_LETTER_TOPIC", "streaming-dead-letters")

  # =============================================================================
  # Redis Configuration
  # =============================================================================

  redis_host = System.get_env("REDIS_HOST", "localhost")
  redis_port = String.to_integer(System.get_env("REDIS_PORT", "6379"))

  redix_args = [
    host: redis_host,
    port: redis_port
  ]

  # Add password if provided
  redix_args =
    case System.get_env("REDIS_PASSWORD") do
      nil -> redix_args
      "" -> redix_args
      password -> Keyword.put(redix_args, :password, password)
    end

  # =============================================================================
  # DeadLetter Configuration
  # =============================================================================

  config :dead_letter,
    driver: [
      module: DeadLetter.Carrier.Kafka,
      init_args: [
        endpoints: kafka_brokers,
        topic: dead_letter_topic
      ]
    ]

  # =============================================================================
  # Brook Configuration for All Services
  # =============================================================================

  # Common brook driver configuration
  brook_driver_config = [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: kafka_brokers,
      topic: event_stream_topic,
      consumer_config: [
        begin_offset: :earliest,
        offset_reset_policy: :reset_to_earliest
      ]
    ]
  ]

  # Common brook storage configuration using Redis
  brook_storage_redis = fn namespace ->
    [
      module: Brook.Storage.Redis,
      init_arg: [
        redix_args: redix_args,
        namespace: namespace
      ]
    ]
  end

  # Alchemist Brook Configuration
  config :alchemist, :brook,
    instance: :alchemist,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "alchemist-events")
    end),
    handlers: [Alchemist.Event.EventHandler],
    storage: brook_storage_redis.("alchemist:view")

  # Alchemist Libcluster Configuration (if running in Kubernetes)
  if System.get_env("RUN_IN_KUBERNETES") do
    config :libcluster,
      topologies: [
        alchemist_cluster: [
          strategy: Elixir.Cluster.Strategy.Kubernetes,
          config: [
            mode: :dns,
            kubernetes_node_basename: "alchemist",
            kubernetes_selector: "app.kubernetes.io/name=alchemist",
            polling_interval: 10_000
          ]
        ]
      ]
  end

  # Andi Brook Configuration
  config :andi, :brook,
    instance: :andi,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "andi-events")
    end),
    handlers: [Andi.Event.EventHandler],
    storage: brook_storage_redis.("andi:view")

  # Discovery API Brook Configuration
  config :discovery_api, :brook,
    instance: :discovery_api,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "discovery-api-events")
    end),
    handlers: [DiscoveryApi.Event.EventHandler],
    storage: brook_storage_redis.("discovery_api:view")

  # Discovery Streams Brook Configuration
  config :discovery_streams, :brook,
    instance: :discovery_streams,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "discovery-streams-events")
    end),
    handlers: [DiscoveryStreams.Event.EventHandler],
    storage: brook_storage_redis.("discovery_streams:view")

  # Forklift Brook Configuration
  config :forklift, :brook,
    instance: :forklift,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "forklift-events")
    end),
    handlers: [Forklift.Event.EventHandler],
    storage: brook_storage_redis.("forklift:view")

  # Raptor Brook Configuration
  config :raptor, :brook,
    instance: :raptor,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "raptor-events")
    end),
    handlers: [Raptor.Event.EventHandler],
    storage: brook_storage_redis.("raptor:view")

  # Reaper Brook Configuration
  config :reaper, :brook,
    instance: :reaper,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "reaper-events")
    end),
    handlers: [Reaper.Event.EventHandler],
    storage: brook_storage_redis.("reaper:view")

  # Template Brook Configuration
  config :template, :brook,
    instance: :template,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "template-events")
    end),
    handlers: [Template.Event.EventHandler],
    storage: brook_storage_redis.("template:view")

  # Valkyrie Brook Configuration
  config :valkyrie, :brook,
    instance: :valkyrie,
    driver: Keyword.update!(brook_driver_config, :init_arg, fn init_arg ->
      Keyword.put(init_arg, :group, "valkyrie-events")
    end),
    handlers: [Valkyrie.Event.EventHandler],
    storage: brook_storage_redis.("valkyrie:view")

  # =============================================================================
  # Additional Service-Specific Configuration
  # =============================================================================

  # Kafka endpoints for services that need them directly
  config :andi,
    kafka_endpoints: kafka_brokers,
    dead_letter_topic: dead_letter_topic

  config :discovery_api,
    elsa_brokers: kafka_brokers,
    dead_letter_topic: dead_letter_topic

  # Discovery API Prestige (Trino/Presto) Configuration
  prestige_url = System.get_env("PRESTO_URL", "http://ride-trino:8080")

  config :prestige, :session_opts,
    url: prestige_url

  # Discovery API Elasticsearch Configuration
  elasticsearch_protocol =
    case System.get_env("ELASTICSEARCH_TLS_ENABLED") do
      "true" -> "https"
      _ -> "http"
    end

  elasticsearch_host = System.get_env("ELASTICSEARCH_HOST")

  if elasticsearch_host do
    config :discovery_api, :elasticsearch,
      url: "#{elasticsearch_protocol}://#{elasticsearch_host}",
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
  end

  config :forklift,
    elsa_brokers: kafka_brokers

  config :reaper,
    elsa_brokers: kafka_brokers

  # Configure Reaper Quantum Scheduler storage (Redis)
  config :reaper, Reaper.Scheduler,
    storage: Reaper.Quantum.Storage,
    global: true,
    overlap: false

  config :reaper, Reaper.Quantum.Storage, redix_args

  config :valkyrie,
    elsa_brokers: kafka_brokers

  config :alchemist,
    elsa_brokers: kafka_brokers,
    input_topic_prefix: System.get_env("INPUT_TOPIC_PREFIX", "raw"),
    output_topic_prefix: System.get_env("OUTPUT_TOPIC_PREFIX", "transformed"),
    processor_stages: String.to_integer(System.get_env("PROCESSOR_STAGES", "1")),
    profiling_enabled: System.get_env("PROFILING_ENABLED") == "true"

  # Alchemist Telemetry Configuration
  config :telemetry_event,
    metrics_port: String.to_integer(System.get_env("METRICS_PORT", "9568")),
    add_metrics: [:dead_letters_handled_count]

  config :discovery_streams,
    elsa_brokers: kafka_brokers

  # Redis configuration for services that use it
  config :redix,
    args: redix_args

  # =============================================================================
  # Logging Configuration
  # =============================================================================

  # Log the configuration on startup (without sensitive data)
  require Logger

  Logger.info("""
  =============================================================================
  Runtime Configuration Loaded (MIX_ENV=#{config_env()})
  =============================================================================
  Kafka Brokers: #{inspect(kafka_brokers)}
  Event Stream Topic: #{event_stream_topic}
  Dead Letter Topic: #{dead_letter_topic}
  Redis Host: #{redis_host}:#{redis_port}
  Redis Password: #{if redix_args[:password], do: "***SET***", else: "not set"}
  Prestige URL: #{prestige_url}

  Brook instances configured:
    - alchemist
    - andi
    - discovery_api
    - discovery_streams
    - forklift
    - raptor
    - reaper
    - template
    - valkyrie

  DeadLetter driver: DeadLetter.Carrier.Kafka
  =============================================================================
  """)
end
