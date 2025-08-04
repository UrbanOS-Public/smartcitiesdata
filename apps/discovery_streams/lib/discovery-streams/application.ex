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
        {Brook, brook()},
        DiscoveryStreams.Stream.Registry,
        DiscoveryStreams.Stream.Supervisor,
        DiscoveryStreams.Init
      ]
      |> TelemetryEvent.config_init_server(@instance_name)
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