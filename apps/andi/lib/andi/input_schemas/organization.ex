defmodule Andi.InputSchemas.Organization do
  @moduledoc """
  Module for validating Ecto.Changesets on organization input
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Organizations
  alias Andi.Schemas.User

  getter(:org_name_max_length, generic: true)

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "organizations" do
    field(:description, :string)
    field(:orgName, :string)
    field(:orgTitle, :string)
    field(:homepage, :string)
    field(:logoUrl, :string)
    field(:dataJsonUrl, :string)
    belongs_to(:org_owner, User, type: Ecto.UUID, foreign_key: :org_owner_id)
  end

  use Accessible

  @cast_fields [
    :id,
    :description,
    :orgName,
    :orgTitle,
    :homepage,
    :logoUrl,
    :dataJsonUrl
  ]

  @required_fields [
    :id,
    :orgName,
    :orgTitle,
    :description
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
    |> validate_length(:orgName, max: org_name_max_length())
    |> validate_id()
  end

  def validate_unique_org_name(changeset) do
    id = Ecto.Changeset.get_field(changeset, :id)
    org_name = Ecto.Changeset.get_field(changeset, :orgName)

    case Organizations.is_unique?(id, org_name) do
      false ->
        add_org_name_error(changeset)

      _ ->
        changeset
    end
  end

  defp validate_id(changeset) do
    id = Ecto.Changeset.get_field(changeset, :id)

    case Ecto.UUID.cast(id) do
      :error -> add_error(changeset, :id, "must be a valid UUID")
      _ -> changeset
    end
  end

  defp add_org_name_error(changeset) do
    changeset
    |> clear_org_name_errors()
    |> add_error(:orgName, "organization name already exists")
  end

  defp clear_org_name_errors(changeset) do
    cleared_errors = Keyword.drop(changeset.errors, [:orgName])

    Map.put(changeset, :errors, cleared_errors)
  end
end
