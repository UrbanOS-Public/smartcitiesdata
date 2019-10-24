defmodule DiscoveryApiWeb.OrganizationController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Schemas.Organizations

  plug(:accepts, ["json"])

  def fetch_detail(conn, %{"id" => id}) do
    case Organizations.get_organization(id) do
      {:error, _} -> render_error(conn, 404, "Not Found")
      {:ok, result} -> render(conn, :fetch_organization, org: result)
    end
  end
end
