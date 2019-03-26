defmodule DiscoveryApiWeb.OrganizationController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  @cache :org_cache

  def fetch_organization(conn, %{"id" => id}) do
    case get_org(id) do
      nil -> render_error(conn, 404, "Not Found")
      result -> render(conn, :fetch_organization, org: result)
    end
  end

  defp get_org(id) do
    read_from_cache(id) || read_from_redis(id)
  end

  defp read_from_cache(id) do
    Cachex.get!(@cache, id)
  end

  defp read_from_redis(id) do
    org = SmartCity.Organization.get(id)
    Cachex.put(@cache, id, org)
    org
  end

  def cache_name() do
    @cache
  end
end
