defmodule Andi.InputSchemas.Datasets.Technical do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.DatasetSchemaValidator
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.Datasets.Header
  alias Andi.InputSchemas.Datasets.QueryParam

  @no_dashes_regex ~r/^[^\-]+$/

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "technical" do
    field(:dataName, :string)
    field(:orgName, :string)
    field(:private, :boolean)
    has_many(:schema, DataDictionary, on_replace: :delete)
    field(:sourceFormat, :string)
    has_many(:sourceHeaders, Header, on_replace: :delete)
    has_many(:sourceQueryParams, QueryParam, on_replace: :delete)
    field(:sourceType, :string)
    field(:systemName, :string)
    field(:sourceUrl, :string)
    field(:topLevelSelector, :string)
    field(:cadence, :string)
    field(:orgId, :string)

    belongs_to(:dataset, Dataset, type: :string, foreign_key: :dataset_id)
  end

  use Accessible

  @cast_fields [
    :id,
    :dataName,
    :orgName,
    :private,
    :sourceFormat,
    :sourceType,
    :sourceUrl,
    :topLevelSelector,
    :systemName,
    :orgId,
    :cadence
  ]
  @required_fields [
    :dataName,
    :orgName,
    :private,
    :sourceFormat,
    :sourceType,
    :sourceUrl
  ]

  def changeset(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)

    technical
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset/2, invalid_message: "is required")
    |> cast_assoc(:sourceHeaders, with: &Header.changeset/2)
    |> cast_assoc(:sourceQueryParams, with: &QueryParam.changeset/2)
    |> foreign_key_constraint(:dataset_id)
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:orgName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_top_level_selector()
    |> validate_schema()
    |> validate_key_value_parameters()
  end

  def changeset_for_draft(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)

    technical
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset_for_draft/2)
    |> cast_assoc(:sourceHeaders, with: &Header.changeset_for_draft/2)
    |> cast_assoc(:sourceQueryParams, with: &QueryParam.changeset_for_draft/2)
    |> foreign_key_constraint(:dataset_id)
  end

  def preload(struct), do: StructTools.preload(struct, [:schema, :sourceQueryParams, :sourceHeaders])

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format}} = changeset)
       when source_format in ["xml", "text/xml"] do
    validate_required(changeset, [:topLevelSelector], message: "is required")
  end

  defp validate_top_level_selector(changeset), do: changeset

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

  defp validate_key_value_parameters(changeset) do
    [:sourceQueryParams, :sourceHeaders]
    |> Enum.reduce(changeset, fn field, acc_changeset ->
      acc_changeset = clear_field_errors(acc_changeset, field)

      if has_invalid_key_values?(acc_changeset, field) do
        add_error(acc_changeset, field, "has invalid format", validation: :format)
      else
        acc_changeset
      end
    end)
  end

  defp has_invalid_key_values?(%{changes: changes}, field) do
    case Map.get(changes, field) do
      nil ->
        false

      key_value_changesets ->
        Enum.any?(key_value_changesets, fn key_value_changeset -> not key_value_changeset.valid? end)
    end
  end

  defp clear_field_errors(changset, field) do
    Map.update(changset, :errors, [], fn errors -> Keyword.delete(errors, field) end)
  end
end
