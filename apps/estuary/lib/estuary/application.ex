defmodule Estuary.Application do
  @moduledoc false
  use Application
  use Properties, otp_app: :estuary

  getter(:init_server, generic: true)

  def start(_type, _args) do
    [
      EstuaryWeb.Endpoint,
      Estuary.Quantum.Scheduler
    ]
    |> config_init_server()
    |> List.flatten()
    |> Supervisor.start_link(strategy: :one_for_one, name: Estuary.Supervisor)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EstuaryWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp config_init_server(child) do
    case init_server() do
      false -> child
      _ -> [{Estuary.InitServer, []} | child]
    end
  end
end
