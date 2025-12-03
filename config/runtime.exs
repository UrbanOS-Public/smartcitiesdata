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
    driver: brook_driver_config,
    handlers: [Alchemist.Event.EventHandler],
    storage: brook_storage_redis.("alchemist:view")

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

  config :forklift,
    elsa_brokers: kafka_brokers

  config :reaper,
    elsa_brokers: kafka_brokers

  config :valkyrie,
    elsa_brokers: kafka_brokers

  config :alchemist,
    elsa_brokers: kafka_brokers

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
