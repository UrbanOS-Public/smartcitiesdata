defmodule Valkyrie.Application do
  @moduledoc false

  use Application
  require Cachex.Spec

  @ttl Application.get_env(:valkyrie, :ttl)

  def start(_type, _args) do
    children =
      [
        {DynamicSupervisor, strategy: :one_for_one, name: Valkyrie.Topic.Supervisor},
        cachex(),
        dataset_subscriber()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dataset_subscriber() do
    case Application.get_env(:smart_city_registry, :redis) do
      nil -> []
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Valkyrie.DatasetHandler]}
    end
  end

  defp cachex do
    expiration = Cachex.Spec.expiration(default: @ttl)

    %{
      id: :dataset_cache,
      start: {Cachex, :start_link, [Valkyrie.Dataset.cache_name(), [expiration: expiration]]}
    }
  end
end
