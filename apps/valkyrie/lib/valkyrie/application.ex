defmodule Valkyrie.Application do
  @moduledoc false

  use Application
  use Properties, otp_app: :valkyrie

  require Cachex.Spec

  @instance_name Valkyrie.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    children =
      [
        libcluster(),
        {DynamicSupervisor, strategy: :one_for_one, name: Valkyrie.Dynamic.Supervisor},
        brook_instance(),
        {Valkyrie.Init, monitor: Valkyrie.Dynamic.Supervisor}
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp brook_instance() do
    config = brook() |> Keyword.put(:instance, @instance_name)
    {Brook, config}
  end

  defp libcluster() do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end
end
