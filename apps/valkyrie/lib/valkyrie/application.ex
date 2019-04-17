defmodule Valkyrie.Application do
  @moduledoc false

  use Application
  require Cachex.Spec

  @ttl Application.get_env(:valkyrie, :ttl)

  def start(_type, _args) do
    children =
      [
        cachex(),
        dataset_subscriber(),
        kaffe()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Valkyrie.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp kaffe do
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
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Valkyrie.Dataset.MessageHandler]}
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
