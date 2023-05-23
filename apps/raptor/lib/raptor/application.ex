defmodule Raptor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Properties, otp_app: :raptor
  require Logger

  @instance_name Raptor.instance_name()

  getter(:brook, generic: true)

  def redis_client(), do: :raptor_redix

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RaptorWeb.Telemetry,
      {Brook, brook()},
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
    Supervisor.start_link(children, opts)
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
