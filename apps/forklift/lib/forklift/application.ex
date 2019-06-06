defmodule Forklift.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        redis(),
        kaffe_consumer(),
        {Forklift.Datasets.DatasetRegistryServer, name: Forklift.Datasets.DatasetRegistryServer},
        dataset_subscriber()
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

  defp kaffe_consumer do
    Application.get_env(:kaffe, :consumer)[:endpoints]
    |> case do
      nil ->
        []

      _ ->
        %{
          id: Kaffe.GroupMemberSupervisor,
          start: {Kaffe.GroupMemberSupervisor, :start_link, []},
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
