defmodule CotaStreamingConsumer.MetricsExporter do
  @moduledoc "false"
  use Prometheus.PlugExporter
end

defmodule CotaStreamingConsumer.Application do
  @moduledoc "false"
  use Application

  require Cachex.Spec

  @cache Application.get_env(:cota_streaming_consumer, :cache)
  @ttl Application.get_env(:cota_streaming_consumer, :ttl)

  def start(_type, _args) do
    import Supervisor.Spec

    CotaStreamingConsumer.MetricsExporter.setup()
    CotaStreamingConsumerWeb.Endpoint.Instrumenter.setup()

    opts = [strategy: :one_for_one, name: CotaStreamingConsumer.Supervisor]

    children =
      [
        cachex(),
        supervisor(CotaStreamingConsumerWeb.Endpoint, []),
        libcluster(),
        CotaStreamingConsumer.CacheGenserver,
        kaffe()
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
      nil ->
        []

      topologies ->
        {Cluster.Supervisor, [topologies, [name: StreamingConsumer.ClusterSupervisor]]}
    end
  end

  defp kaffe do
    case Application.get_env(:kaffe, :consumer) do
      nil -> []
      _ -> Supervisor.Spec.supervisor(Kaffe.GroupMemberSupervisor, [])
    end
  end

  defp cachex do
    expiration = Cachex.Spec.expiration(default: @ttl)

    %{
      id: Cachex,
      start: {Cachex, :start_link, [@cache, [expiration: expiration]]}
    }
  end
end
