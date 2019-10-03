defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Forklift.MetricsExporter.setup()
    init_topic_writer()

    children =
      [
        libcluster(),
        redis(),
        metrics(),
        {DynamicSupervisor, strategy: :one_for_one, name: Forklift.Dynamic.Supervisor},
        migrations(),
        Forklift.Quantum.Scheduler,
        {Brook, Application.get_env(:forklift, :brook)},
        {DeadLetter, Application.get_env(:forklift, :dead_letter)},
        Forklift.Init
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def redis_client(), do: :redix

  defp init_topic_writer do
    instance_name = :forklift

    case Application.get_env(instance_name, :output_topic) do
      nil -> []
      topic -> do_init_topic_writer(instance_name, topic)
    end
  end

  defp do_init_topic_writer(instance, topic) do
    config = [
      instance: instance,
      endpoints: Application.get_env(instance, :elsa_brokers),
      topic: topic,
      producer_name: Application.get_env(instance, :producer_name),
      retry_count: Application.get_env(instance, :retry_count),
      retry_delay: Application.get_env(instance, :retry_initial_delay)
    ]

    Pipeline.Writer.SingleTopicWriter.init(config)
  end

  defp redis do
    case Application.get_env(:redix, :host) do
      nil -> []
      host -> {Redix, host: host, name: redis_client()}
    end
  end

  defp migrations do
    case Application.get_env(:redix, :host) do
      nil -> []
      _host -> Forklift.Migrations
    end
  end

  defp metrics() do
    case Application.get_env(:forklift, :metrics_port) do
      nil ->
        []

      metrics_port ->
        Plug.Cowboy.child_spec(
          scheme: :http,
          plug: Forklift.MetricsExporter,
          options: [port: metrics_port]
        )
    end
  end

  defp libcluster do
    case Application.get_env(:libcluster, :topologies) do
      nil -> []
      topology -> {Cluster.Supervisor, [topology, [name: Cluster.ClusterSupervisor]]}
    end
  end
end
