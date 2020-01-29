defmodule DiscoveryApiWeb.OrganizationView do
  use DiscoveryApiWeb, :view

  def render("fetch_organization.json", %{org: org}) do
    %{
      id: org.id,
      name: org.name,
      title: org.title,
      description: org.description,
      homepage: org.homepage,
      logoUrl: org.logo_url
    }
  end
end
