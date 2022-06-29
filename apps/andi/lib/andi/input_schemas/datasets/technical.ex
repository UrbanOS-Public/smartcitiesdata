defmodule Andi.InputSchemas.Datasets.Technical do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.Datasets.Header
  alias Andi.InputSchemas.Datasets.QueryParam

  @no_dashes_regex ~r/^[^\-]+$/

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "technical" do
    field(:allow_duplicates, :boolean)
    field(:authBody, :map)
    field(:authBodyEncodeMethod, :string)
    field(:authHeaders, :map)
    field(:authUrl, :string)
    field(:credentials, :boolean)
    field(:dataName, :string)
    field(:orgId, :string)
    field(:orgName, :string)
    field(:private, :boolean)
    field(:protocol, {:array, :string})
    field(:sourceType, :string)
    field(:sourceUrl, :string)
    field(:systemName, :string)
    field(:topLevelSelector, :string)
    has_many(:schema, DataDictionary, on_replace: :delete)
    has_many(:sourceHeaders, Header, on_replace: :delete)
    has_many(:sourceQueryParams, QueryParam, on_replace: :delete)

    belongs_to(:dataset, Dataset, type: :string, foreign_key: :dataset_id)
  end

  use Accessible

  @cast_fields [
    :allow_duplicates,
    :authBody,
    :authBodyEncodeMethod,
    :authHeaders,
    :authUrl,
    :credentials,
    :dataName,
    :id,
    :orgId,
    :orgName,
    :private,
    :protocol,
    :sourceType,
    :sourceUrl,
    :systemName,
    :topLevelSelector
  ]
  @required_fields [
    :dataName,
    :orgName,
    :private,
    :sourceType
  ]

  @submission_cast_fields [
    :dataName
  ]

  @submission_required_fields [
    :dataName
  ]

  def changeset(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)

    technical
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2), invalid_message: "is required")
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

  def submission_changeset(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)

    technical
    |> cast(changes_with_id, @submission_cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2), invalid_message: "is required")
    |> foreign_key_constraint(:dataset_id)
    |> validate_required(@submission_required_fields, message: "is required")
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_submission_schema()
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

  defp validate_top_level_selector(changeset), do: changeset

  defp validate_schema(%{changes: %{sourceType: source_type}} = changeset)
       when source_type in ["ingest", "stream"] do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
      [] -> add_error(changeset, :schema, "cannot be empty")
      nil -> add_error(changeset, :schema, "is required", validation: :required)
      _ -> changeset
    end
  end

  defp validate_schema(changeset), do: changeset

  defp validate_submission_schema(%{changes: %{schema: _}} = changeset) do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
      [] ->
        add_error(changeset, :schema, "cannot be empty")

      nil ->
        add_error(changeset, :schema, "is required", validation: :required)

      _ ->
        changeset
    end
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

  defp clear_field_errors(changeset, field) do
    Map.update(changeset, :errors, [], fn errors -> Keyword.delete(errors, field) end)
  end
end
