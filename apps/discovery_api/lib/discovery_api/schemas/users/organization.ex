defmodule DiscoveryApi.Schemas.Organizations.Organization do
  @moduledoc """
  Ecto schema respresentation of the Organization.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  schema "organizations" do
    field(:name, :string)
    field(:title, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:logo_url, :string)
    field(:ldap_dn, :string)

    timestamps()
  end

  def changeset(organization, changes) do
    organization
    |> cast(changes, [:name, :title, :description, :homepage, :logo_url, :ldap_dn])
    |> validate_required([:name, :title, :ldap_dn])
    |> unique_constraint(:id)
  end
end
