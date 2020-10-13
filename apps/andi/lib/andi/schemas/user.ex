defmodule Andi.Schemas.User do
  @moduledoc """
  Ecto schema respresentation of the User.
  """
  use Ecto.Schema
  alias Andi.Repo
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "users" do
    field(:subject_id, :string)
    field(:email, :string)
  end

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

  def get_by_subject_id(subject_id) do
    Repo.get_by(__MODULE__, subject_id: subject_id)
  end
end
