defmodule Andi.InputSchemas.Datasets.ExtractStep do
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias Andi.InputSchemas.StructTools

  @cast_fields [:context, :type, :technical_id]
  @required_fields [:type, :context]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "extract_step" do
    field(:type, :string)
    field(:context, :map)
    belongs_to(:technical, Technical, type: Ecto.UUID, foreign_key: :technical_id)
  end

  use Accessible

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @cast_fields)
    |> validate_required(@required_fields, message: "is required")
    |> validate_type()
    |> validate_context()
  end

  def validate_type(%{changes: %{type: type}} = changeset) when type in ["http", "date"] do
    changeset
  end
  def validate_type(changeset), do: add_error(changeset, :type, "invalid type")

  def validate_context(%{changes: %{context: nil}} = changeset), do: changeset
  def validate_context(%{changes: %{type: type, context: context}} = changeset) do
    case step_module(type) do
      :invalid_type ->
        changeset
      step_module ->
        validated_context = step_module.changeset(context)
        merged_errors = validated_context.errors ++ changeset.errors

        Map.put(changeset, :errors, merged_errors)
    end
  end
  def validate_context(changeset), do: changeset

  def step_module("http"), do: Andi.InputSchemas.Datasets.ExtractHttpStep
  def step_module("date"), do: Andi.InputSchemas.Datasets.ExtractDateStep
  def step_module(_invalid_type), do: :invalid_type
end
