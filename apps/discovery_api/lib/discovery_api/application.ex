defmodule DiscoveryApi.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    DiscoveryApi.MetricsExporter.setup()
    DiscoveryApiWeb.Endpoint.Instrumenter.setup()

    children =
      [
        supervisor(DiscoveryApiWeb.Endpoint, []),
        redis(),
        dataset_event_consumer()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: DiscoveryApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    DiscoveryApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil -> []
      host -> {Redix, host: host, name: :redix}
    end
  end

  defp dataset_event_consumer do
    Application.get_env(:kaffe, :consumer)[:endpoints]
    |> case do
      nil ->
        []

      _ ->
        [
          %{
            id: Kaffe.Consumer,
            start: {Kaffe.Consumer, :start_link, []},
            type: :supervisor
          }
        ]
    end
  end
end
