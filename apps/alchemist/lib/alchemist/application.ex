defmodule Alchemist.Application do
  @moduledoc false

  use Application
  use Properties, otp_app: :alchemist

  require Cachex.Spec
  require Logger

  @instance_name Alchemist.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    Logger.info("======================================================")
    Logger.info("Alchemist.Application starting...")
    Logger.info("======================================================")

    # Log node distribution configuration for debugging
    Logger.info("Node name: #{inspect(Node.self())}")
    Logger.info("Node alive?: #{Node.alive?()}")
    Logger.info("HOSTNAME env: #{System.get_env("HOSTNAME")}")
    Logger.info("RELEASE_NODE env: #{System.get_env("RELEASE_NODE")}")
    Logger.info("RELEASE_DISTRIBUTION env: #{System.get_env("RELEASE_DISTRIBUTION")}")

    # Verify :pg module is available (part of kernel application in OTP 23+)
    # Start :pg if Brook has a Kafka driver configured (production)
    # In test mode with ETS storage, Brook manages :pg internally
    brook_config = Application.get_env(:alchemist, :brook, [])
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

    children =
      [
        libcluster(),
        {DynamicSupervisor, strategy: :one_for_one, name: Alchemist.Dynamic.Supervisor},
        brook_instance(),
        {Alchemist.Init, monitor: Alchemist.Dynamic.Supervisor}
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Alchemist.Supervisor]
    Supervisor.start_link(children, opts)
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
end
