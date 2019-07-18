defmodule Valkyrie.Application do
  @moduledoc false

  use Application
  require Cachex.Spec

  def start(_type, _args) do
    children =
      [
        {DynamicSupervisor, strategy: :one_for_one, name: Valkyrie.Dynamic.Supervisor},
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
end
