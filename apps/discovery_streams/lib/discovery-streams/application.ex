defmodule DiscoveryStreams.Application do
  @moduledoc false
  use Application
  use Properties, otp_app: :discovery_streams
  require Cachex.Spec

  @instance_name DiscoveryStreams.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    require Logger
    import Supervisor.Spec

    Logger.info("======================================================")
    Logger.info("DiscoveryStreams.Application starting...")
    Logger.info("======================================================")

    # Verify :pg module is available (part of kernel application in OTP 23+)
    # Start :pg if Brook has a Kafka driver configured (production)
    # In test mode with Brook.Driver.Test, Brook manages :pg internally
    brook_config = Application.get_env(:discovery_streams, :brook, [])
    driver_config = Keyword.get(brook_config, :driver, [])
    has_kafka_driver = Keyword.get(driver_config, :module) == Brook.Driver.Kafka

    if Code.ensure_loaded?(:pg) and has_kafka_driver do
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

    # Manually start brook_stream to control initialization order
    Logger.info("Manually starting brook_stream application...")

    case Application.ensure_all_started(:brook_stream) do
      {:ok, started_apps} ->
        Logger.info("Successfully started brook_stream and dependencies: #{inspect(started_apps)}")

      {:error, {app, reason}} ->
        Logger.error("Failed to start #{app}: #{inspect(reason)}")
    end

    opts = [strategy: :one_for_one, name: DiscoveryStreams.Supervisor]

    children =
      [
        {Phoenix.PubSub, [name: DiscoveryStreams.PubSub, adapter: Phoenix.PubSub.PG2]},
        supervisor(DiscoveryStreamsWeb.Endpoint, []),
        libcluster(),
        {Brook, brook()},
        DiscoveryStreams.Stream.Registry,
        DiscoveryStreams.Stream.Supervisor,
        DiscoveryStreams.Init,
        dead_letter_children()
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    Supervisor.start_link(children, opts)
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topologies -> {Cluster.Supervisor, [topologies, [name: StreamingConsumer.ClusterSupervisor]]}
    end
  end

  defp dead_letter_children() do
    require Logger
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
end
