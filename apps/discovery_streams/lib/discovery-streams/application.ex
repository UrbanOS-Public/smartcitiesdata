defmodule DiscoveryStreams.Application do
  @moduledoc false
  use Application
  use Properties, otp_app: :discovery_streams
  require Cachex.Spec

  @instance_name DiscoveryStreams.instance_name()

  getter(:brook, generic: true)

  def start(_type, _args) do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: DiscoveryStreams.Supervisor]

    children =
      [
        {Phoenix.PubSub, [name: DiscoveryStreams.PubSub, adapter: Phoenix.PubSub.PG2]},
        supervisor(DiscoveryStreamsWeb.Endpoint, []),
        libcluster(),
        DiscoveryStreams.Stream.Registry,
        DiscoveryStreams.Stream.Supervisor
      ]
      |> brook_child()
      |> init_child()
      |> TelemetryEvent.config_init_server(@instance_name)
      |> List.flatten()

    Supervisor.start_link(children, opts)
  end

  defp brook_child(children) do
    if Application.get_env(:discovery_streams, :start_brook, true) do
      children ++ [{Brook, brook()}]
    else
      children
    end
  end

  defp init_child(children) do
    if Application.get_env(:discovery_streams, :start_init, true) do
      children ++ [DiscoveryStreams.Init]
    else
      children
    end
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topologies -> {Cluster.Supervisor, [topologies, [name: StreamingConsumer.ClusterSupervisor]]}
    end
  end
end
