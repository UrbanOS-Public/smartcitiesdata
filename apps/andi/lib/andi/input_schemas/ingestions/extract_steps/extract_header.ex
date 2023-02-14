defmodule Andi.InputSchemas.Ingestions.ExtractHeader do
  @moduledoc false
  use Ecto.Schema

  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  embedded_schema do
    field(:key, :string)
    field(:value, :string)
  end

  use Accessible

  @cast_fields [:id, :key, :value]
  @required_fields [:key]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(header, changes) do
    common_changeset_operations(header, changes)
    |> Changeset.validate_required(@required_fields, message: "is required")
  end

  def validate(changeset) do
    data_as_changes =
      changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    validated_changeset = changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
      |> Changeset.validate_required(@required_fields, message: "is required")

    if is_nil(Map.get(validated_changeset, :action, nil)) do
      Map.put(validated_changeset, :action, :display_errors)
    else
      validated_changeset
    end
  end

  def changeset_for_draft(header, changes) do
    common_changeset_operations(header, changes)
  end

  defp common_changeset_operations(header, changes) do
    changes_with_id = StructTools.ensure_id(header, changes)

    Changeset.cast(header, changes_with_id, @cast_fields, empty_values: [])
  end

  def preload(struct), do: struct
end
