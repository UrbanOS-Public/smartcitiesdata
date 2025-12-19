defmodule DiscoveryApi.Application do
  @moduledoc """
  Discovery API serves as middleware between our metadata store and our Data Discovery UI.
  """
  use Application
  use Properties, otp_app: :discovery_api

  @instance_name DiscoveryApi.instance_name()

  getter(:brook, generic: true)
  getter(:elasticsearch, generic: true)

  def start(_type, _args) do
    require Logger
    import Supervisor.Spec

    Logger.info("======================================================")
    Logger.info("DiscoveryApi.Application starting...")
    Logger.info("======================================================")

    # Validate required configuration
    validate_required_config!()

    # Verify :pg module is available (part of kernel application in OTP 23+)
    # Start :pg if Brook has a Kafka driver configured (production)
    # In test mode with Brook.Driver.Test, Brook manages :pg internally
    brook_config = Application.get_env(:discovery_api, :brook, [])
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

    get_s3_credentials()

    children =
      [
        {Phoenix.PubSub, [name: DiscoveryApi.PubSub, adapter: Phoenix.PubSub.PG2]},
        DiscoveryApi.Data.SystemNameCache,
        DiscoveryApiWeb.Plugs.ResponseCache,
        redis(),
        ecto_repo(),
        guardian_db_sweeper(),
        {Brook, brook()},
        cache_populator(),
        supervisor(DiscoveryApiWeb.Endpoint, []),
        DiscoveryApi.Quantum.Scheduler,
        DiscoveryApi.Data.TableInfoCache,
        dead_letter_children()
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    # Only initialize Elasticsearch index if elasticsearch is configured
    if elasticsearch() do
      Logger.info("Elasticsearch configured, creating index if missing...")
      DiscoveryApi.Search.Elasticsearch.DatasetIndex.create_if_missing()
    else
      Logger.info("Elasticsearch not configured, skipping index creation")
    end

    opts = [strategy: :one_for_one, name: DiscoveryApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    DiscoveryApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp redis do
    case Application.get_env(:redix, :args) do
      nil -> []
      redix_args -> {Redix, Keyword.put(redix_args, :name, :redix)}
    end
  end

  def get_env_variable(var_name) do
    var = System.get_env(var_name)

    if is_nil(var) || String.length(var) == 0 do
      raise RuntimeError,
        message: "Could not start application, required #{var_name} is not set."
    end

    var
  end

  defp get_s3_credentials do
    Application.put_env(:ex_aws, :access_key_id, get_env_variable("AWS_ACCESS_KEY_ID"))
    Application.put_env(:ex_aws, :secret_access_key, get_env_variable("AWS_ACCESS_KEY_SECRET"))
  end

  defp ecto_repo do
    Application.get_env(:discovery_api, DiscoveryApi.Repo)
    |> case do
      nil -> []
      _ -> [{DiscoveryApi.Repo, []}, DiscoveryApi.Data.VisualizationMigrator]
    end
  end

  defp guardian_db_sweeper do
    Application.get_env(:discovery_api, Guardian.DB)
    |> case do
      nil ->
        []

      config ->
        Application.put_env(:guardian, Guardian.DB, config)
        Supervisor.Spec.worker(Guardian.DB.Token.SweeperServer, [])
    end
  end

  defp cache_populator do
    elasticsearch()
    |> case do
      nil -> []
      _ -> DiscoveryApi.Data.CachePopulator
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

  defp validate_required_config! do
    require Logger

    # Check both sources: environment variable (production) and application config (test/dev)
    env_raptor_url = System.get_env("RAPTOR_URL")
    app_raptor_url = Application.get_env(:discovery_api, :raptor_url)

    raptor_url = env_raptor_url || app_raptor_url

    if is_nil(raptor_url) or raptor_url == "" do
      Logger.error("CRITICAL: RAPTOR_URL is not configured")
      Logger.error("Neither RAPTOR_URL environment variable nor :raptor_url application config is set")
      Logger.error("Please set one of:")
      Logger.error("  - Environment variable: RAPTOR_URL=http://raptor:4002/api")
      Logger.error("  - Application config: config :discovery_api, raptor_url: \"http://raptor:4002/api\"")
      raise "RAPTOR_URL must be configured via environment variable or application config"
    end

    Logger.info("Configuration validation passed: RAPTOR_URL=#{raptor_url}")
  end
end
