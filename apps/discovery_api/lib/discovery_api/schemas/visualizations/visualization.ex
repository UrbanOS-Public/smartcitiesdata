defmodule DiscoveryApi.Schemas.Visualizations.Visualization do
  @moduledoc """
  Ecto schema representation of a data visualization.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Generators

  schema "visualizations" do
    field(:public_id, :string, autogenerate: {Generators, :generate_public_id, []})
    field(:query, :string)
    field(:title, :string)
    field(:chart, :string)
    field(:datasets, {:array, :string})
    field(:valid_query, :boolean)
    belongs_to(:owner, User, type: Ecto.UUID, foreign_key: :owner_id)

    timestamps()
  end

  @doc false
  def changeset(visualization, changes) do
    {owner, changes} = Map.pop(changes, :owner)

    visualization
    |> cast(changes, [:query, :title, :chart])
    |> validate_length(:chart, count: :bytes, max: 20_000)
    |> validate_length(:query, count: :bytes, max: 20_000)
    |> put_assoc(:owner, owner)
    |> foreign_key_constraint(:owner_id)
    |> validate_required([:query, :title, :owner])
    |> unique_constraint(:public_id)
  end

  @doc false
  def changeset_update(visualization, changes) do
    visualization
    |> cast(changes, [:query, :title, :chart, :datasets, :valid_query])
    |> validate_length(:chart, count: :bytes, max: 20_000)
    |> validate_required([:query, :title])
  end
end
