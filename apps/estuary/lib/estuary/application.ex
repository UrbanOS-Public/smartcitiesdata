defmodule Estuary.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    [
      EstuaryWeb.Endpoint,
      Estuary.Quantum.Scheduler,
      {Estuary.InitServer, []}
    ]
    |> List.flatten()
    |> Supervisor.start_link(strategy: :one_for_one, name: Estuary.Supervisor)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EstuaryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
