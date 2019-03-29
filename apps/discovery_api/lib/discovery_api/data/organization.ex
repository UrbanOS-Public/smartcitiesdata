defmodule DiscoveryApi.Data.Organization do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  @cache :org_cache

  def get(id) do
    case Cachex.get(@cache, id) do
      {:ok, nil} -> read_from_redis(id)
      {:ok, result} -> {:ok, result}
    end
  end

  defp read_from_redis(id) do
    with {:ok, org} <- SmartCity.Organization.get(id),
         {:ok, _} <- Cachex.put(@cache, id, org) do
      {:ok, org}
    else
      error -> error
    end
  end

  def cache_name() do
    @cache
  end
end
