defmodule Andi.InputSchemas.AccessGroup do
  @moduledoc """
  Module for validating Ecto.Changesets on access group input
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Schemas.User
  alias AndiWeb.Views.Options

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "access_groups" do
    field(:name, :string)
    field(:description, :string)
    many_to_many(:users, User, join_through: Andi.Schemas.UserAccessGroup)
    many_to_many(:datasets, Dataset, join_through: Andi.Schemas.DatasetAccessGroup)
  end

  use Accessible

  @cast_fields [
    :id,
    :name
  ]

  @required_fields [
    :name
  ]

  def changeset(%SmartCity.AccessGroup{} = changes) do
    changes_as_map = StructTools.to_map(changes)
    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(access_group, changes) do
    changes_with_id = StructTools.ensure_id(access_group, changes)

    access_group
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
    |> validate_id()
  end

  defp validate_id(changeset) do
    id = Ecto.Changeset.get_field(changeset, :id)

    case Ecto.UUID.cast(id) do
      :error -> add_error(changeset, :id, "must be a valid UUID")
      _ -> changeset
    end
  end
end
