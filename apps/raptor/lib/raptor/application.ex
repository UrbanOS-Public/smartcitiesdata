defmodule Raptor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Properties, otp_app: :raptor

  @instance_name Raptor.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RaptorWeb.Telemetry,
      {Brook, brook()},
      # Start the PubSub system
      {Phoenix.PubSub, [name: Raptor.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start the Endpoint (http/https)
      RaptorWeb.Endpoint
      # Start a worker by calling: Raptor.Worker.start_link(arg)
      # {Raptor.Worker, arg}
    ]

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
end
