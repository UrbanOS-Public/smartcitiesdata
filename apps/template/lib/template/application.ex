defmodule Template.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  use Properties, otp_app: :template

  @instance_name Template.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TemplateWeb.Telemetry,
      {Brook, brook()},
      # Start the PubSub system
      {Phoenix.PubSub, [name: Template.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start the Endpoint (http/https)
      TemplateWeb.Endpoint
      # Start a worker by calling: Template.Worker.start_link(arg)
      # {Template.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Template.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TemplateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
