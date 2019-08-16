defmodule DiscoveryApiWeb.OrganizationController do
  use DiscoveryApiWeb, :controller
  alias SmartCity.Organization

  plug(:accepts, ["json"])

  def fetch_detail(conn, %{"id" => id}) do
    case Organization.get(id) do
      {:error, _} -> render_error(conn, 404, "Not Found")
      {:ok, result} -> render(conn, :fetch_organization, org: result)
    end
  end
end
