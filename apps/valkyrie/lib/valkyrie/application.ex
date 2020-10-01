defmodule Valkyrie.Application do
  @moduledoc false
  use Application

  require Cachex.Spec

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]

    children =
      [
        libcluster(),
        {Brook, Application.get_env(:valkyrie, :brook)},
        Valkyrie.Stream.Registry,
        Valkyrie.Stream.Supervisor,
        Valkyrie.Init
      ]
      |> TelemetryEvent.config_init_server(:valkryie)
      |> List.flatten()

    Supervisor.start_link(children, opts)
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topologies -> {Cluster.Supervisor, [topologies, [name: StreamingConsumer.ClusterSupervisor]]}
    end
  end
end
