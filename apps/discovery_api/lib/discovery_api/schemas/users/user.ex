defmodule DiscoveryApi.Schemas.Users.User do
  @moduledoc """
  Ecto schema respresentation of the User.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:subject_id, :string)
    field(:username, :string)

    timestamps()
  end

  @doc false
  def changeset(user, changes) do
    user
    |> cast(changes, [:subject_id, :username])
    |> validate_required([:subject_id, :username])
    |> unique_constraint(:subject_id)
  end
end
