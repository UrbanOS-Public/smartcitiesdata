defmodule Reaper.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        libcluster(),
        {Horde.Registry, [name: Reaper.Registry]},
        {Horde.Supervisor, [name: Reaper.Horde.Supervisor, strategy: :one_for_one]},
        {HordeConnector, [supervisor: Reaper.Horde.Supervisor, registry: Reaper.Registry]},
        {Reaper.ConfigServer, [supervisor: Reaper.Horde.Supervisor, registry: Reaper.Registry]},
        kaffe()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Reaper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp kaffe do
    Application.get_env(:kaffe, :consumer, [])
    |> Keyword.get(:endpoints)
    |> case do
      nil -> []
      _ -> Supervisor.Spec.worker(Kaffe.Consumer, [])
    end
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end
end
