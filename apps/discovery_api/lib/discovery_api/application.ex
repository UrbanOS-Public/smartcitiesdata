defmodule DiscoveryApi.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    DiscoveryApi.MetricsExporter.setup()
    DiscoveryApiWeb.Endpoint.Instrumenter.setup()

    children = [
      cachex(),
      supervisor(DiscoveryApiWeb.Endpoint, []),
      discoverApiCacheLoader()
    ]
    |> List.flatten()

    opts = [strategy: :one_for_one, name: DiscoveryApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    DiscoveryApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp cachex do
    %{
      id: Cachex,
      start: {Cachex, :start_link, [:dataset_cache]}
    }
  end

  defp discoverApiCacheLoader do
    case Application.get_env(:discovery_api, :test_mode) do
      true -> []
      _ -> DiscoveryApi.Data.CacheLoader
    end
  end
end
