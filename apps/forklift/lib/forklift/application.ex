defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        {Registry, [keys: :unique, name: dataset_jobs_registry()]},
        exq(),
        redis(),
        kaffe_consumer(),
        {Forklift.Datasets.DatasetRegistryServer, name: Forklift.Datasets.DatasetRegistryServer},
        Forklift.Messages.EmptyStreamTracker,
        Forklift.Messages.RetryTracker,
        dataset_subscriber(),
        {Forklift.Messages.MessageWriter, name: Forklift.Messages.MessageWriter}
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def dataset_jobs_registry(), do: :dataset_jobs

  defp exq do
    case Application.get_env(:exq, :host) do
      nil ->
        []

      _ ->
        %{
          id: Exq,
          type: :supervisor,
          start: {Exq, :start_link, []}
        }
    end
  end

  def redis_client(), do: Forklift.Redix

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil ->
        []

      host ->
        {Forklift.Redix, host: host}
    end
  end

  defp kaffe_consumer do
    Application.get_env(:kaffe, :consumer)[:endpoints]
    |> case do
      nil ->
        []

      _ ->
        %{
          id: Kaffe.Consumer,
          start: {Kaffe.Consumer, :start_link, []},
          type: :supervisor
        }
    end
  end

  defp dataset_subscriber() do
    case Application.get_env(:smart_city_registry, :redis) do
      nil -> []
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Forklift.Datasets.DatasetHandler]}
    end
  end
end
