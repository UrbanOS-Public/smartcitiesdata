defmodule DiscoveryApiWeb.OrganizationView do
  @moduledoc """
  View for organizations
  """
  use DiscoveryApiWeb, :view

  def render("fetch_organization.json", %{org: org}) do
    org
  end
end
