defmodule DiscoveryApi.Schemas.Organizations do
  @moduledoc """
  Interface for reading and writing the Organization schema.
  """
  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Organizations.Organization

  def list_organizations do
    Repo.all(Organization)
  end

  def create_or_update(%SmartCity.Organization{} = org) do
    create_or_update(org.id, %{
      name: org.orgName,
      title: org.orgTitle,
      description: org.description,
      homepage: org.homepage,
      logo_url: org.logoUrl,
      ldap_dn: org.dn
    })
  end

  def create_or_update(id, changes \\ %{}) do
    case Repo.get(Organization, id) do
      nil -> %Organization{id: id}
      organization -> organization
    end
    |> Organization.changeset(changes)
    |> Repo.insert_or_update()
  end

  def get_organization(id), do: Repo.get(Organization, id)
end
