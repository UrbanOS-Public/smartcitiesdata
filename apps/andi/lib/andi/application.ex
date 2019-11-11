defmodule Andi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      AndiWeb.Endpoint,
      {Brook, Application.get_env(:andi, :brook)},
      Andi.DatasetCache
      Andi.Migration.Migrations
    ]

    opts = [strategy: :one_for_one, name: Andi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AndiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
