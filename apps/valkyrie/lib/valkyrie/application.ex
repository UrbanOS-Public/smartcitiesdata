defmodule Valkyrie.Application do
  @moduledoc false

  use Application
  require Cachex.Spec

  def start(_type, _args) do
    children =
      [
        libcluster(),
        {DynamicSupervisor, strategy: :one_for_one, name: Valkyrie.Dynamic.Supervisor},
        {Brook, Application.get_env(:valkyrie, :brook)},
        Valkyrie.Init
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp libcluster() do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end
end
