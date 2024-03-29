defmodule Andi.Schemas.User do
  @moduledoc """
  Ecto schema respresentation of the User.
  """
  use Ecto.Schema
  alias Andi.Repo
  import Ecto.Changeset
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Organization
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups
  import Ecto.Query, only: [from: 1]

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "users" do
    field(:subject_id, :string)
    field(:name, :string)
    field(:email, :string)
    has_many(:datasets, Dataset, on_replace: :delete, foreign_key: :owner_id)
    many_to_many(:organizations, Organization, join_through: Andi.Schemas.UserOrganization, on_replace: :delete)
    many_to_many(:access_groups, AccessGroup, join_through: Andi.Schemas.UserAccessGroup, on_replace: :delete)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(user, changes) do
    user
    |> cast(changes, [:subject_id, :email, :name])
    |> validate_required([:subject_id, :email, :name])
    |> unique_constraint(:subject_id)
  end

  @spec create_or_update(any, :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}) :: any
  def create_or_update(subject_id, changes \\ %{}) do
    case get_by_subject_id(subject_id) do
      nil -> %__MODULE__{subject_id: subject_id}
      user -> user
    end
    |> changeset(changes)
    |> Repo.insert_or_update()
  end

  def associate_with_access_group(subject_id, access_group_id) do
    with user <- Repo.get_by(__MODULE__, subject_id: subject_id) |> Repo.preload(:access_groups),
         access_group <- AccessGroups.get(access_group_id) do
      user
      |> Repo.preload(:access_groups)
      |> change()
      |> put_assoc(:access_groups, [access_group | user.access_groups])
      |> Repo.update()
    else
      error -> error
    end
  end

  def disassociate_with_access_group(subject_id, access_group_id) do
    with user <- Repo.get_by(__MODULE__, subject_id: subject_id) |> Repo.preload(:access_groups),
         access_group <- AccessGroups.get(access_group_id) do
      updated_access_groups = List.delete(user.access_groups, access_group)

      user
      |> Repo.preload(:access_groups)
      |> change()
      |> put_assoc(:access_groups, updated_access_groups)
      |> Repo.update()
    else
      error -> error
    end
  end

  def associate_with_organization(subject_id, organization_id) do
    with user <- Repo.get_by(__MODULE__, subject_id: subject_id) |> Repo.preload(:organizations),
         org <- Organizations.get(organization_id) do
      user |> Repo.preload(:organizations) |> change() |> put_assoc(:organizations, [org | user.organizations]) |> Repo.update()
    else
      error ->
        error
    end
  end

  def disassociate_with_organization(subject_id, organization_id) do
    with user <- Repo.get_by(__MODULE__, subject_id: subject_id) |> Repo.preload(:organizations),
         org <- Organizations.get(organization_id) do
      updated_orgs = List.delete(user.organizations, org)
      user |> Repo.preload(:organizations) |> change() |> put_assoc(:organizations, updated_orgs) |> Repo.update()
    else
      error -> error
    end
  end

  def get_all() do
    query = from(user in __MODULE__)

    Repo.all(query) |> Repo.preload([:datasets, :organizations])
  end

  def get_by_subject_id(subject_id) do
    Repo.get_by(__MODULE__, subject_id: subject_id) |> Repo.preload([:datasets, :organizations])
  end

  def get_by_id(id) do
    Repo.get_by(__MODULE__, id: id) |> Repo.preload([:datasets, :organizations])
  end

  def preload(struct), do: struct
end
