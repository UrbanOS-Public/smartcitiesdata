defmodule Odo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        {DynamicSupervisor, name: Odo.ShapefileProcessorSupervisor, strategy: :one_for_one},
        redis(),
        dataset_subscriber()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Odo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil -> []
      host -> {Redix, host: host, name: redis_client()}
    end
  end

  defp dataset_subscriber() do
    case Application.get_env(:smart_city_registry, :redis) do
      nil -> []
      _ -> {SmartCity.Registry.Subscriber, [message_handler: Odo.MessageHandler]}
    end
  end
end
