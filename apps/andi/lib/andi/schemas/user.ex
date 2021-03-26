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
  import Ecto.Query, only: [from: 1]

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "users" do
    field(:subject_id, :string)
    field(:email, :string)
    has_many(:datasets, Dataset, on_replace: :delete, foreign_key: :owner_id)
    has_many(:organizations, Organization, on_replace: :delete, foreign_key: :org_owner_id)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(user, changes) do
    user
    |> cast(changes, [:subject_id, :email])
    |> validate_required([:subject_id, :email])
    |> unique_constraint(:subject_id)
  end

  def create_or_update(subject_id, changes \\ %{}) do
    case get_by_subject_id(subject_id) do
      nil -> %__MODULE__{subject_id: subject_id}
      user -> user
    end
    |> changeset(changes)
    |> Repo.insert_or_update()
  end

  def associate_with_organization(subject_id, organization_id) do
    with user <- Repo.get_by(__MODULE__, subject_id: subject_id),
         org <- Organizations.get(organization_id) do
      user |> Repo.preload(:organizations) |> change() |> put_assoc(:organizations, [org]) |> Repo.update()
    else
      error -> error
    end
  end

  def get_all() do
    query = from(user in __MODULE__)

    Repo.all(query) |> Repo.preload([:datasets, :organizations])
  end

  def get_by_subject_id(subject_id) do
    Repo.get_by(__MODULE__, subject_id: subject_id) |> Repo.preload([:datasets])
  end

  def get_by_id(id) do
    Repo.get_by(__MODULE__, id: id) |> Repo.preload([:datasets])
  end

  def preload(struct), do: struct
end
