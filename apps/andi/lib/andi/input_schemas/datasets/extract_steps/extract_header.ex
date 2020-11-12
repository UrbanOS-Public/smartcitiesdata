defmodule Andi.InputSchemas.Datasets.ExtractHeader do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.ExtractHttpStep

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
    |> validate_required(@required_fields, message: "is required")
  end

  def changeset_for_draft(header, changes) do
    common_changeset_operations(header, changes)
  end

  defp common_changeset_operations(header, changes) do
    changes_with_id = StructTools.ensure_id(header, changes)

    cast(header, changes_with_id, @cast_fields, empty_values: [])
  end

  def preload(struct), do: struct
end
