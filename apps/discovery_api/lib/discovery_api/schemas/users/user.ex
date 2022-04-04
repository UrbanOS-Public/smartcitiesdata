defmodule DiscoveryApi.Schemas.Users.User do
  @moduledoc """
  Ecto schema respresentation of the User.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias DiscoveryApi.Schemas.Visualizations.Visualization
  alias DiscoveryApi.Schemas.Organizations.Organization

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "users" do
    field(:subject_id, :string)
    field(:name, :string)
    field(:email, :string)
    has_many(:visualizations, Visualization, foreign_key: :owner_id)
    many_to_many(:organizations, Organization, join_through: DiscoveryApi.Schemas.Users.UserOrganization, on_replace: :delete)

    timestamps()
  end

  @doc false
  def changeset(user, changes) do
    user
    |> cast(changes, [:subject_id, :email, :name])
    |> validate_required([:subject_id, :email, :name])
    |> unique_constraint(:subject_id)
  end

  def changeset_add_organization(user, organization) do
    user
    |> change()
    |> put_assoc(:organizations, [organization | user.organizations])
  end

  def changeset_remove_organization(user, organization) do
    updated_orgs = List.delete(user.organizations, organization)

    user
    |> change()
    |> put_assoc(:organizations, updated_orgs)
  end
end
