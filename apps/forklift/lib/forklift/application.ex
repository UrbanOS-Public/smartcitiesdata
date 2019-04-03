defmodule Forklift.Application do
  @moduledoc false

  use Application

  def redis_client(), do: Forklift.Redix

  def start(_type, _args) do
    children =
      [
        {Registry, keys: :unique, name: Forklift.Registry},
        {Task.Supervisor, name: Forklift.TaskSupervisor},
        {Forklift.MessageWriter, name: Forklift.MessageWriter},
        {Forklift.DatasetRegistryServer, name: Forklift.DatasetRegistryServer},
        Forklift.DataBuffer,
        redis(),
        dataset_subscriber(),
        kaffe()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Forklift.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil ->
        []

      host ->
        {Forklift.Redix, host: host}
    end
  end

  defp dataset_subscriber() do
    case Application.get_env(:smart_city_registry, :redis) do
      nil -> []
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Forklift.MessageProcessor]}
    end
  end

  defp kaffe do
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
end
