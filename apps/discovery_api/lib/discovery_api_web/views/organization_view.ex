defmodule DiscoveryApiWeb.OrganizationView do
  @moduledoc false
  use DiscoveryApiWeb, :view

  def render("fetch_organization.json", %{org: org}) do
    org
  end
end
