defmodule CotaStreamingConsumer.MetricsExporter do
  @moduledoc "false"
  use Prometheus.PlugExporter
end

defmodule CotaStreamingConsumer.Application do
  @moduledoc "false"
  use Application

  require Cachex.Spec

  def start(_type, _args) do
    import Supervisor.Spec

    CotaStreamingConsumer.MetricsExporter.setup()
    CotaStreamingConsumerWeb.Endpoint.Instrumenter.setup()

    opts = [strategy: :one_for_one, name: CotaStreamingConsumer.Supervisor]

    children =
      [
        CotaStreamingConsumer.CachexSupervisor,
        supervisor(CotaStreamingConsumerWeb.Endpoint, []),
        libcluster(),
        CotaStreamingConsumer.CacheGenserver,
        kaffe(),
        CotaStreamingConsumerWeb.Presence,
        CotaStreamingConsumerWeb.Presence.Server
      ]
      |> List.flatten()

    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    CotaStreamingConsumerWeb.Endpoint.config_change(changed, removed)
    :ok
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
          CotaStreamingConsumer.TopicSubscriber
        ]
    end
  end
end
