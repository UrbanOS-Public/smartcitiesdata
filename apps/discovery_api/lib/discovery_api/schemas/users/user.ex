defmodule DiscoveryApi.Schemas.Users.User do
  @moduledoc """
  Ecto schema respresentation of the User.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  schema "users" do
    field(:subject_id, :string)
    field(:email, :string)
    has_many(:visualizations, Visualization, foreign_key: :owner_id)

    timestamps()
  end

  @doc false
  def changeset(user, changes) do
    user
    |> cast(changes, [:subject_id, :email])
    |> validate_required([:subject_id, :email])
    |> unique_constraint(:subject_id)
  end
end
