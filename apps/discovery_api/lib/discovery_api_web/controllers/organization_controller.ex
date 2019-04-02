defmodule DiscoveryApiWeb.OrganizationController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias SmartCity.Organization

  def fetch_organization(conn, %{"id" => id}) do
    case Organization.get(id) do
      {:error, _} -> render_error(conn, 404, "Not Found")
      {:ok, result} -> render(conn, :fetch_organization, org: result)
    end
  end
end
