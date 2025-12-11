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

    # Verify :pg module is available (part of kernel application in OTP 23+)
    # Start :pg if Brook has a Kafka driver configured (production)
    # In test mode with ETS storage, Brook manages :pg internally
    brook_config = Application.get_env(:valkyrie, :brook, [])
    has_driver = Keyword.has_key?(brook_config, :driver)

    if Code.ensure_loaded?(:pg) and has_driver do
      Logger.info("Process group (:pg) module is available and loaded")
      Logger.info("Brook driver detected - ensuring :pg server is running")

      # Ensure the :pg server process is running
      case Process.whereis(:pg) do
        nil ->
          Logger.warning("Process group (:pg) server is NOT running, attempting to start it...")

          case :pg.start_link() do
            {:ok, pid} ->
              Logger.info("Successfully started :pg server (pid: #{inspect(pid)})")

            {:error, {:already_started, pid}} ->
              Logger.info(":pg server already started (pid: #{inspect(pid)})")

            {:error, reason} ->
              Logger.error("CRITICAL: Failed to start :pg server: #{inspect(reason)}")
          end

        pid ->
          Logger.info("Process group (:pg) server is running (pid: #{inspect(pid)})")
      end
    end

    # Log Brook configuration
    log_brook_configuration(brook_config)

    # Log registered processes before starting Brook
    log_registered_processes()

    # Manually start brook_stream to control initialization order
    Logger.info("Manually starting brook_stream application...")

    case Application.ensure_all_started(:brook_stream) do
      {:ok, started_apps} ->
        Logger.info("Successfully started brook_stream and dependencies: #{inspect(started_apps)}")

      {:error, {app, reason}} ->
        Logger.error("Failed to start #{app}: #{inspect(reason)}")
    end

    children =
      [
        libcluster(),
        {DynamicSupervisor, strategy: :one_for_one, name: Valkyrie.Dynamic.Supervisor},
        brook_instance(),
        dead_letter_children(),
        {Valkyrie.Init, monitor: Valkyrie.Dynamic.Supervisor}
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    # Log the final children list
    Logger.info("Supervisor children to start:")

    Enum.with_index(children, 1)
    |> Enum.each(fn {child, idx} ->
      case child do
        {module, _config} -> Logger.info("  #{idx}. #{inspect(module)}")
        {module, _config, _opts} -> Logger.info("  #{idx}. #{inspect(module)}")
        module when is_atom(module) -> Logger.info("  #{idx}. #{inspect(module)}")
        _ -> Logger.info("  #{idx}. #{inspect(child)}")
      end
    end)

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

    Logger.info("Brook instance configuration (with instance name added):")
    Logger.info("  Instance: #{inspect(config[:instance])}")
    Logger.info("  Full config keys: #{inspect(Keyword.keys(config))}")

    {Brook, config}
  end

  defp dead_letter_children() do
    Logger.info("Initializing DeadLetter children...")

    opts = Application.get_all_env(:dead_letter)

    case Keyword.fetch(opts, :driver) do
      {:ok, driver_config} ->
        config = Enum.into(driver_config, %{init_args: [size: 3000]})

        Logger.info("DeadLetter will start with driver: #{inspect(config.module)}")

        [
          {config.module, config.init_args},
          {DeadLetter.Server, config}
        ]

      :error ->
        Logger.warn("DeadLetter configuration not found, skipping DeadLetter initialization")
        []
    end
  end

  defp libcluster() do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end

  defp log_registered_processes() do
    Logger.info("Registered processes before starting Brook:")

    registered = Process.registered()

    # Filter to show Brook-related, Redis-related, and Kafka-related processes
    relevant_processes =
      registered
      |> Enum.filter(fn name ->
        name_str = Atom.to_string(name)

        String.contains?(name_str, "Brook") or
          String.contains?(name_str, "brook") or
          String.contains?(name_str, "Redix") or
          String.contains?(name_str, "redix") or
          String.contains?(name_str, "Kafka") or
          String.contains?(name_str, "kafka") or
          String.contains?(name_str, "brod") or
          String.contains?(name_str, "Elsa") or
          String.contains?(name_str, "valkyrie")
      end)

    if Enum.empty?(relevant_processes) do
      Logger.info("  No Brook/Redis/Kafka related processes registered")
    else
      Logger.info("  Found #{length(relevant_processes)} relevant processes:")

      Enum.each(relevant_processes, fn name ->
        Logger.info("    - #{inspect(name)}")
      end)
    end

    Logger.info("  Total registered processes: #{length(registered)}")

    # Log ALL started applications to identify what's starting brod
    Logger.info("Started OTP applications:")
    started_apps = Application.started_applications()

    Enum.each(started_apps, fn {app, _desc, _vsn} ->
      Logger.info("  - #{inspect(app)}")
    end)

    Logger.info("  Total started applications: #{length(started_apps)}")
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
