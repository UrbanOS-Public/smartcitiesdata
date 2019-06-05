defmodule DiscoveryApiWeb.OrganizationView do
  use DiscoveryApiWeb, :view

  def render("fetch_organization.json", %{org: org}) do
    org
  end
end
