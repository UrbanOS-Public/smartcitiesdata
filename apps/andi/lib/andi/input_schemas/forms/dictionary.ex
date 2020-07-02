defmodule Andi.InputSchemas.Form.Dictionary do
  @moduledoc """
  Module for validating Ecto.Changesets on flattened dataset input.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DatasetSchemaValidator

  schema "data_dictionary" do
    has_many(:schema, DataDictionary, on_replace: :delete)
  end

  use Accessible

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(dictionary, changes) do
    source_format = Map.get(changes, :sourceFormat, nil)
    changes_with_id = StructTools.ensure_id(dictionary, changes)

    dictionary
    |> cast(changes_with_id, [], empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2, source_format), invalid_message: "is required")
    |> validate_required(:schema, message: "is required")
    |> validate_schema()
  end

  def changeset_from_andi_dataset(dataset) do
    dataset = StructTools.to_map(dataset)
    technical_changes = dataset.technical

    changeset(technical_changes)
  end

  # def changeset_for_draft(dataset, changes) do
  #   dataset
  #   |> cast(changes, @cast_fields)
  #   |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
  #   |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  # end

  defp validate_schema(%{changes: %{sourceType: source_type}} = changeset)
  when source_type in ["ingest", "stream"] do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
      [] -> add_error(changeset, :schema, "cannot be empty")
      nil -> add_error(changeset, :schema, "is required", validation: :required)
      _ -> validate_schema_internals(changeset)
    end
  end

  defp validate_schema(changeset), do: changeset

  defp validate_schema_internals(%{changes: changes} = changeset) do
    schema =
      Ecto.Changeset.get_field(changeset, :schema, [])
      |> StructTools.to_map()

    DatasetSchemaValidator.validate(schema, changes[:sourceFormat])
    |> Enum.reduce(changeset, fn error, changeset_acc -> add_error(changeset_acc, :schema, error) end)
  end
end
