defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Forklift.MetricsExporter.setup()

    children =
      [
        redis(),
        {DynamicSupervisor, strategy: :one_for_one, name: Forklift.Topic.Supervisor},
        {Forklift.Datasets.DatasetRegistryServer, name: Forklift.Datasets.DatasetRegistryServer},
        dataset_subscriber(),
        Forklift.Quantum.Scheduler,
        metrics()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def redis_client(), do: :redix

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil ->
        []

      host ->
        {Redix, host: host, name: redis_client()}
    end
  end

  defp dataset_subscriber() do
    case Application.get_env(:smart_city_registry, :redis) do
      nil -> []
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Forklift.Datasets.DatasetHandler]}
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
end
