defmodule DiscoveryStreams.Application do
  @moduledoc false
  use Application

  require Cachex.Spec

  def start(_type, _args) do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: DiscoveryStreams.Supervisor]

    children =
      [
        supervisor(DiscoveryStreamsWeb.Endpoint, []),
        libcluster(),
        {Brook, Application.get_env(:discovery_streams, :brook)},
        DiscoveryStreams.Stream.Registry,
        DiscoveryStreams.Stream.Supervisor
        # {DiscoveryStreams.Init},
      ]
      |> TelemetryEvent.config_init_server(:discovery_streams)
      |> List.flatten()

    Supervisor.start_link(children, opts)
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topologies -> {Cluster.Supervisor, [topologies, [name: StreamingConsumer.ClusterSupervisor]]}
    end
  end

  # defp init do
  #   case Application.get_env(:discovery_streams, :todo) do
  #     nil -> []
  #     _ -> DiscoveryStreams.SourceSupervisor
  #   end
  # end
end
