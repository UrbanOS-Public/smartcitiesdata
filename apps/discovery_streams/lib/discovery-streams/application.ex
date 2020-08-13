defmodule DiscoveryStreams.Application do
  @moduledoc false
  use Application

  require Cachex.Spec

  def start(_type, _args) do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: DiscoveryStreams.Supervisor]

    children =
      [
        DiscoveryStreams.CachexSupervisor,
        supervisor(DiscoveryStreamsWeb.Endpoint, []),
        libcluster(),
        DiscoveryStreams.CacheGenserver,
        {Brook, Application.get_env(:discovery_streams, :brook)},
        kaffe(),
        DiscoveryStreamsWeb.Presence,
        DiscoveryStreamsWeb.Presence.Server
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

  defp kaffe do
    case Application.get_env(:kaffe, :consumer)[:endpoints] do
      nil ->
        []

      _ ->
        [
          Supervisor.Spec.supervisor(Kaffe.GroupMemberSupervisor, []),
          DiscoveryStreams.TopicSubscriber
        ]
    end
  end
end
