defmodule DiscoveryApi.Application do
  @moduledoc false
  use Application
  require Cachex.Spec

  @ttl Application.get_env(:discovery_api, :ttl)

  def start(_type, _args) do
    import Supervisor.Spec

    DiscoveryApi.MetricsExporter.setup()
    DiscoveryApiWeb.Endpoint.Instrumenter.setup()

    children =
      [
        cachex(),
        supervisor(DiscoveryApiWeb.Endpoint, []),
        registry_pubsub(),
        redis()
      ]
      |> List.flatten()

    opts = [strategy: :one_for_one, name: DiscoveryApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    DiscoveryApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp registry_pubsub() do
    Application.get_env(:smart_city_registry, :redis)
    |> case do
      nil -> []
      [host: _] -> {SmartCity.Registry.Subscriber, [message_handler: DiscoveryApi.Data.DatasetEventListener]}
    end
  end

  defp redis do
    Application.get_env(:redix, :host)
    |> case do
      nil -> []
      host -> {Redix, host: host, name: :redix}
    end
  end

  defp cachex do
    expiration = Cachex.Spec.expiration(default: @ttl)

    %{
      id: DiscoveryApiWeb.OrganizationController.cache_name(),
      start: {Cachex, :start_link, [DiscoveryApiWeb.OrganizationController.cache_name(), [expiration: expiration]]}
    }
  end
end
