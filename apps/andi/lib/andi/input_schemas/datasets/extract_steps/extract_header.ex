defmodule Andi.InputSchemas.Datasets.ExtractHeader do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "extract_http_headers" do
    field(:key, :string)
    field(:value, :string)
    belongs_to(:extract_http_step, ExtractHttpStep, type: Ecto.UUID, foreign_key: :extract_http_step_id)
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

    header
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> foreign_key_constraint(:extract_http_step_id)
  end

  def preload(struct), do: struct
end
