defmodule Raptor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Properties, otp_app: :raptor
  require Logger

  getter(:brook, generic: true)

  def redis_client(), do: :raptor_redix

  def start(_type, _args) do
    Logger.info("======================================================")
    Logger.info("Raptor.Application starting...")
    Logger.info("======================================================")

    # Log Brook configuration
    brook_config = brook()
    log_brook_configuration(brook_config)

    # Log Redis configuration
    redix_config = Application.get_env(:redix, :args, [])
    Logger.info("Raptor Redis configuration:")
    Logger.info("  Redix args: #{inspect(redix_config)}")

    children = [
      # Start the Telemetry supervisor
      RaptorWeb.Telemetry,
      {Brook, brook_config},
      redis(),
      # Start the PubSub system
      {Phoenix.PubSub, [name: Raptor.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start the Endpoint (http/https)
      RaptorWeb.Endpoint
      # Start a worker by calling: Raptor.Worker.start_link(arg)
      # {Raptor.Worker, arg}
    ]

    set_auth0_credentials()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raptor.Supervisor]

    Logger.info("Starting Raptor supervisor...")
    result = Supervisor.start_link(children, opts)

    case result do
      {:ok, pid} ->
        Logger.info("Raptor.Application started successfully (pid: #{inspect(pid)})")
        Logger.info("======================================================")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Raptor.Application failed to start: #{inspect(reason)}")
        Logger.error("======================================================")
        {:error, reason}
    end
  end

  defp log_brook_configuration(brook_config) do
    Logger.info("Raptor Brook configuration:")

    if is_nil(brook_config) do
      Logger.error("""
      FATAL: Brook configuration is nil!

      Required configuration:
        config :raptor, :brook,
          instance: :raptor,
          driver: [
            module: Brook.Driver.Kafka,
            init_arg: [endpoints: [...], topic: "event-stream", group: "raptor-events"]
          ],
          handlers: [Raptor.Event.EventHandler],
          storage: [
            module: Brook.Storage.Redis,
            init_arg: [redix_args: [...], namespace: "raptor:view"]
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
      Logger.info("  Instance: #{inspect(Keyword.get(brook_config, :instance))}")

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
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    RaptorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def is_invalid_env_variable(var) do
    is_nil(var) || String.length(var) == 0
  end

  def get_env_variable(var_name, throw_if_absent) do
    var = System.get_env(var_name)

    if is_invalid_env_variable(var) do
      Logger.warn("Required environment variable #{var_name} is nil.")

      if throw_if_absent do
        raise RuntimeError,
          message: "Could not start application, required #{var_name} is nil."
      end
    end

    var
  end

  defp redis() do
    Application.get_env(:redix, :args, [])
    |> case do
      nil -> []
      redix_args -> {Redix, Keyword.put(redix_args, :name, redis_client())}
    end
  end

  def set_auth0_credentials() do
    Application.put_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth,
      domain: get_env_variable("AUTH0_DOMAIN", false),
      client_id: get_env_variable("RAPTOR_AUTH0_CLIENT_ID", false),
      client_secret: get_env_variable("AUTH0_CLIENT_SECRET", false)
    )
  end
end
