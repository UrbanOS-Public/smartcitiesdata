defmodule DiscoveryApiWeb.OrganizationController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  @cache :org_cache

  def fetch_organization(conn, %{"id" => id}) do
    case get_org(id) do
      {:error, _} -> render_error(conn, 404, "Not Found")
      {:ok, result} -> render(conn, :fetch_organization, org: result)
    end
  end

  defp get_org(id) do
    case Cachex.get(@cache, id) do
      {:ok, nil} -> read_from_redis(id)
      {:ok, result} -> {:ok, result}
    end
  end

  defp read_from_redis(id) do
    org = SmartCity.Organization.get(id)

    case org do
      {:error, reason} -> {:error, reason}
      {:ok, value} -> Cachex.put(@cache, id, value)
    end

    org
  end

  def cache_name() do
    @cache
  end
end
