defmodule Andi.InputSchemas.DatasetInput do
  @moduledoc """
  Module for validating Ecto.Changesets on flattened dataset input.
  """
  import Ecto.Changeset

  alias Andi.DatasetCache
  alias Andi.InputSchemas.DatasetSchemaValidator
  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.KeyValue

  @business_fields %{
    benefitRating: :float,
    contactEmail: :string,
    contactName: :string,
    dataTitle: :string,
    description: :string,
    homepage: :string,
    issuedDate: :date,
    keywords: {:array, :string},
    language: :string,
    license: :string,
    modifiedDate: :date,
    orgTitle: :string,
    publishFrequency: :string,
    riskRating: :float,
    spatial: :string,
    temporal: :string
  }

  @technical_fields %{
    dataName: :string,
    orgName: :string,
    private: :boolean,
    schema: {:array, :map},
    sourceFormat: :string,
    sourceHeaders: {:embed, KeyValue.relationship_definition(:sourceHeaders)},
    sourceQueryParams: {:embed, KeyValue.relationship_definition(:sourceQueryParams)},
    sourceType: :string,
    sourceUrl: :string,
    topLevelSelector: :string
  }

  @types %{id: :string}
         |> Map.merge(@business_fields)
         |> Map.merge(@technical_fields)

  @key_value_type_keys [:sourceQueryParams, :sourceHeaders]

  @non_embedded_types Map.drop(@types, @key_value_type_keys)

  @required_fields [
    :benefitRating,
    :contactEmail,
    :contactName,
    :dataName,
    :dataTitle,
    :description,
    :issuedDate,
    :license,
    :orgName,
    :orgTitle,
    :private,
    :publishFrequency,
    :riskRating,
    :sourceFormat,
    :sourceType,
    :sourceUrl
  ]

  @email_regex ~r/^[\w\_\~\!\$\&\'\(\)\*\+\,\;\=\:.-]+@[\w.-]+\.[\w.-]+?$/
  @no_dashes_regex ~r/^[^\-]+$/
  @ratings Map.keys(Options.ratings())

  def business_keys(), do: Map.keys(@business_fields)
  def technical_keys(), do: Map.keys(@technical_fields)
  def key_value_keys(), do: @key_value_type_keys

  def light_validation_changeset(changes), do: light_validation_changeset(%{}, changes)

  def light_validation_changeset(schema, changes) do
    {schema, @types}
    |> cast(changes, Map.keys(@non_embedded_types), empty_values: [])
    |> cast_embedded()
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:contactEmail, @email_regex)
    |> validate_format(:orgName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_inclusion(:benefitRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_inclusion(:riskRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_top_level_selector()
    |> validate_schema()
    |> validate_key_value_parameters()
  end

  def full_validation_changeset(changes), do: full_validation_changeset(%{}, changes)

  def full_validation_changeset(schema, changes) do
    light_validation_changeset(schema, changes) |> validate_unique_system_name()
  end

  def add_key_value(changeset, field, %{} = param \\ %{}) do
    new_key_value_changeset = KeyValue.changeset(%KeyValue{}, param)

    change =
      case fetch_change(changeset, field) do
        {:ok, params} -> params ++ [new_key_value_changeset]
        _ -> [new_key_value_changeset]
      end

    put_change(changeset, field, change)
  end

  def remove_key_value(changeset, field, id) do
    update_change(changeset, field, fn params ->
      Enum.filter(params, fn param -> param.changes.id != id end)
    end)
    |> validate_key_value_parameters()
  end

  defp cast_embedded(changeset) do
    Enum.reduce(@key_value_type_keys, changeset, fn key, acc_changeset -> cast_embed(acc_changeset, key) end)
  end

  defp validate_unique_system_name(changeset) do
    if has_unique_data_and_org_name?(changeset) do
      changeset
    else
      add_error(changeset, :dataName, "existing dataset has the same orgName and dataName")
    end
  end

  defp has_unique_data_and_org_name?(%{changes: changes}) do
    DatasetCache.get_all()
    |> Enum.filter(&Map.has_key?(&1, "dataset"))
    |> Enum.map(& &1["dataset"])
    |> Enum.all?(fn existing_dataset ->
      changes[:orgName] != existing_dataset.technical.orgName ||
        changes[:dataName] != existing_dataset.technical.dataName ||
        changes[:id] == existing_dataset.id
    end)
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format}} = changeset)
       when source_format in ["xml", "text/xml"] do
    validate_required(changeset, [:topLevelSelector], message: "is required")
  end

  defp validate_top_level_selector(changeset), do: changeset

  defp validate_schema(%{changes: %{sourceType: source_type}} = changeset)
       when source_type in ["ingest", "stream"] do
    case Map.get(changeset.changes, :schema) do
      [] -> add_error(changeset, :schema, "cannot be empty")
      nil -> add_error(changeset, :schema, "is required", validation: :required)
      _ -> validate_schema_internals(changeset)
    end
  end

  defp validate_schema(changeset), do: changeset

  defp validate_schema_internals(%{changes: changes} = changeset) do
    DatasetSchemaValidator.validate(changes[:schema], changes[:sourceFormat])
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
