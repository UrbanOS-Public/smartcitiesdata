defmodule Valkyrie.Application do
  @moduledoc false

  use Application
  use Properties, otp_app: :valkyrie

  require Logger
  require Cachex.Spec

  @instance_name Valkyrie.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    Logger.info("======================================================")
    Logger.info("Valkyrie.Application starting...")
    Logger.info("======================================================")

    # Log Brook configuration
    brook_config = brook()
    log_brook_configuration(brook_config)

    children =
      [
        libcluster(),
        {DynamicSupervisor, strategy: :one_for_one, name: Valkyrie.Dynamic.Supervisor},
        brook_instance(),
        {Valkyrie.Init, monitor: Valkyrie.Dynamic.Supervisor}
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]

    Logger.info("Starting Valkyrie supervisor...")
    result = Supervisor.start_link(children, opts)

    case result do
      {:ok, pid} ->
        Logger.info("Valkyrie.Application started successfully (pid: #{inspect(pid)})")
        Logger.info("======================================================")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Valkyrie.Application failed to start: #{inspect(reason)}")
        Logger.error("======================================================")
        {:error, reason}
    end
  end

  defp brook_instance() do
    config = brook() |> Keyword.put(:instance, @instance_name)
    {Brook, config}
  end

  defp libcluster() do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end

  defp log_brook_configuration(brook_config) do
    Logger.info("Valkyrie Brook configuration:")

    if is_nil(brook_config) do
      Logger.error("""
      FATAL: Brook configuration is nil!

      Required configuration:
        config :valkyrie, :brook,
          instance: :valkyrie,
          driver: [
            module: Brook.Driver.Kafka,
            init_arg: [endpoints: [...], topic: "event-stream", group: "valkyrie-events"]
          ],
          handlers: [Valkyrie.Event.EventHandler],
          storage: [
            module: Brook.Storage.Redis,
            init_arg: [redix_args: [...], namespace: "valkyrie:view"]
          ]

      Please check:
      1. config/runtime.exs exists and is being loaded (MIX_ENV=prod)
      2. Environment variables are set:
         - KAFKA_BROKERS (default: localhost:9092)
         - EVENT_STREAM_TOPIC (default: event-stream)
         - REDIS_HOST (default: localhost)
         - REDIS_PORT (default: 6379)
      3. The release was built with the latest configuration
      """)
    else
      # Brook config will have :instance added by brook_instance/0, so we log before that
      driver = Keyword.get(brook_config, :driver, [])
      Logger.info("  Driver module: #{inspect(driver[:module])}")

      if driver[:init_arg] do
        Logger.info("  Driver endpoints: #{inspect(driver[:init_arg][:endpoints])}")
        Logger.info("  Driver topic: #{inspect(driver[:init_arg][:topic])}")
        Logger.info("  Driver group: #{inspect(driver[:init_arg][:group])}")
      end

      handlers = Keyword.get(brook_config, :handlers, [])
      Logger.info("  Handlers: #{inspect(handlers)}")

      storage = Keyword.get(brook_config, :storage, [])
      Logger.info("  Storage module: #{inspect(storage[:module])}")

      if storage[:init_arg] do
        Logger.info("  Storage namespace: #{inspect(storage[:init_arg][:namespace])}")
        # Don't log full redix_args as it might contain passwords
        Logger.info("  Storage redix configured: #{not is_nil(storage[:init_arg][:redix_args])}")
      end

      Logger.info("  Instance (will be set to): :#{@instance_name}")
    end
  end
end
