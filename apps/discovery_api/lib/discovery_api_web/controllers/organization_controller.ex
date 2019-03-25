defmodule DiscoveryApiWeb.OrganizationController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Data.Persistence

  @name_space "smart_city:organization:latest:"

  @cache :org_cache

  def fetch_organization(conn, %{"id" => id}) do
    case get_org(id) do
      nil -> render_error(conn, 404, "Not Found")
      result -> render(conn, :fetch_organization, org: result)
    end
  end

  defp get_org(id) do
    case Cachex.get!(@cache, id) do
      nil -> sync_org(id)
      value -> value
    end
  end

  defp sync_org(id) do
    org = Persistence.get(@name_space <> id)

    case org do
      _ -> add_to_cache(id, org)
      nil -> nil
    end
  end

  defp add_to_cache(id, org) do
    Cachex.put(@cache, id, org)
    org
  end

  def cache_name() do
    @cache
  end
end
