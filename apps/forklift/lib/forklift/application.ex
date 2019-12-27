defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Forklift.MetricsExporter.setup()

    children =
      [
        libcluster(),
        redis(),
        metrics(),
        {DynamicSupervisor, strategy: :one_for_one, name: Forklift.Dynamic.Supervisor},
        Forklift.Quantum.Scheduler,
        {Brook, Application.get_env(:forklift, :brook)},
        migrations(),
        {DeadLetter, Application.get_env(:forklift, :dead_letter)},
        Forklift.InitServer
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def redis_client(), do: :redix

  defp redis do
    case Application.get_env(:redix, :args) do
      nil -> []
      redix_args -> {Redix, Keyword.put(redix_args, :name, redis_client())}
    end
  end

  defp migrations do
    case Application.get_env(:redix, :args) do
      nil -> []
      _args -> Forklift.Migrations
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
