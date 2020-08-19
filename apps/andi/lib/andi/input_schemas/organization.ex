defmodule Andi.InputSchemas.Organization do
  @moduledoc """
  Module for validating Ecto.Changesets on organization input
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "organizations" do
    field(:description, :string)
    field(:orgName, :string)
    field(:orgTitle, :string)
    field(:homepage, :string)
    field(:logoUrl, :string)
    field(:dataJSONUrl, :string)
  end

  use Accessible

  @cast_fields [
    :id,
    :orgName,
    :orgTitle,
    :homepage,
    :logoUrl,
    :dataJSONUrl
  ]

  @required_fields [
    :id,
    :orgName,
    :orgTitle
  ]

  def changeset(%SmartCity.Organization{} = changes) do
    changes_as_map = StructTools.to_map(changes)
    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(organization, changes) do
    changes_with_id = StructTools.ensure_id(organization, changes)

    organization
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
  end
end
