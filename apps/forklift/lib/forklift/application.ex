defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Forklift.MetricsExporter.setup()

    children =
      [
        libcluster(),
        redis(),
        elsa_producer(),
        metrics(),
        {DynamicSupervisor, strategy: :one_for_one, name: Forklift.Dynamic.Supervisor},
        Forklift.Quantum.Scheduler,
        {Brook, Application.get_env(:forklift, :brook)},
        Forklift.Init
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def redis_client(), do: :redix

  defp redis do
    case Application.get_env(:redix, :host) do
      nil -> []
      host -> {Redix, host: host, name: redis_client()}
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

  defp elsa_producer() do
    case Application.get_env(:forklift, :output_topic) do
      nil ->
        []

      output_topic ->
        {
          Elsa.Producer.Supervisor,
          name: Application.get_env(:forklift, :producer_name),
          endpoints: Application.get_env(:forklift, :elsa_brokers),
          topic: output_topic
        }
    end
  end
end
