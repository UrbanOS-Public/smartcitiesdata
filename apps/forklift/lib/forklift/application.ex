defmodule Forklift.Application do
  @moduledoc false

  use Application
  use Properties, otp_app: :forklift

  require Logger

  @instance_name Forklift.instance_name()

  getter(:brook, generic: true)
  getter(:table_writer, generic: true)
  getter(:secrets_endpoint, generic: true)

  def start(_type, _args) do
    Logger.info("======================================================")
    Logger.info("Forklift.Application starting...")
    Logger.info("======================================================")

    # Verify :pg module is available (part of kernel application in OTP 23+)
    # Start :pg if Brook has a Kafka driver configured (production)
    # In test mode with Brook.Driver.Test, Brook manages :pg internally
    brook_config = Application.get_env(:forklift, :brook, [])
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

    children =
      [
        # libcluster() - DISABLED due to FQDN/short name conflicts
        redis(),
        {DynamicSupervisor, strategy: :one_for_one, name: Forklift.Dynamic.Supervisor},
        Forklift.Quantum.Scheduler,
        {Brook, brook()},
        migrations(),
        dead_letter_children(),
        Forklift.InitServer
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    if table_writer() == Pipeline.Writer.S3Writer do
      fetch_and_set_s3_credentials()
    end

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Logger.info("Starting forklift to fork or lift.")
    Supervisor.start_link(children, opts)
  end

  def redis_client(), do: :redix

  defp redis do
    case Application.get_env(:redix, :args) do
      nil -> []
      redix_args -> {Redix, Keyword.put(redix_args, :name, redis_client())}
    end
  end

  defp migrations do
    case Application.get_env(:redix, :args) do
      nil -> []
      _args -> Forklift.Migrations
    end
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
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

  defp fetch_and_set_s3_credentials() do
    endpoint = secrets_endpoint()

    if is_nil(endpoint) || String.length(endpoint) == 0 do
      Logger.warn(
        "No secrets endpoint. Forklift will need to explicitly define a secret id and key to interact with the object store"
      )

      []
    else
      case Forklift.SecretRetriever.retrieve_objectstore_keys() do
        nil ->
          raise RuntimeError, message: "Could not start application, failed to retrieve credentials from storage"

        {:error, error} ->
          raise RuntimeError,
            message: "Could not start application, encountered error while retrieving credentials: #{error}"

        {:ok, creds} ->
          Application.put_env(:ex_aws, :access_key_id, Map.get(creds, "aws_access_key_id"))
          Application.put_env(:ex_aws, :secret_access_key, Map.get(creds, "aws_secret_access_key"))
      end
    end
  end
end
