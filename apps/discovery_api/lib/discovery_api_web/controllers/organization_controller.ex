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
    id
    |> read_from_cache()
    |> read_from_redis(id)
  end

  defp read_from_cache(id) do
    Cachex.get!(@cache, id)
  end

  defp read_from_redis(nil, id) do
    org = Persistence.get(@name_space <> id)
    Cachex.put(@cache, id, org)
    org
  end

  defp read_from_redis(org, _), do: org

  def cache_name() do
    @cache
  end
end
