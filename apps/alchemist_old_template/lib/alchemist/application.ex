defmodule Alchemist.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Properties, otp_app: :alchemist

  @instance_name Alchemist.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      AlchemistWeb.Telemetry,
      {Brook, brook()},
      # Start the PubSub system
      {Phoenix.PubSub, [name: Alchemist.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start the Endpoint (http/https)
      AlchemistWeb.Endpoint
      # Start a worker by calling: Alchemist.Worker.start_link(arg)
      # {Alchemist.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alchemist.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AlchemistWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
