defmodule Andi.InputSchemas.DatasetInput do
  @moduledoc """
  Module for validating Ecto.Changesets on flattened dataset input.
  """
  import Ecto.Changeset

  alias Andi.DatasetCache
  alias Andi.InputSchemas.DatasetSchemaValidator
  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.KeyValue

  #TODO: make this suck less
  @params_embedded_key_values %Ecto.Embedded{
    cardinality: :many,
    field: :sourceQueryParams,
    on_cast: &KeyValue.changeset(&1, &2),
    on_replace: :delete,
    owner: nil,
    related: KeyValue
  }

  @headers_embedded_key_values %Ecto.Embedded{
    cardinality: :many,
    field: :sourceHeaders,
    on_cast: &KeyValue.changeset(&1, &2),
    on_replace: :delete,
    owner: nil,
    related: KeyValue
  }

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
    sourceHeaders: {:embed, @headers_embedded_key_values},
    sourceType: :string,
    sourceQueryParams: {:embed, @params_embedded_key_values},
    sourceUrl: :string,
    topLevelSelector: :string
  }

  @types %{id: :string}
         |> Map.merge(@business_fields)
         |> Map.merge(@technical_fields)

  @non_embedded_types Map.drop(@types, [:sourceQueryParams, :sourceHeaders])

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

  @email_regex ~r/^[A-Za-z0-9._%+-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/
  @no_dashes_regex ~r/^[^\-]+$/
  @ratings Map.keys(Options.ratings())

  def business_keys(), do: Map.keys(@business_fields)
  def technical_keys(), do: Map.keys(@technical_fields)

  def light_validation_changeset(changes), do: light_validation_changeset(%{}, changes)

  def light_validation_changeset(schema, changes) do
    {schema, @types}
    |> cast(changes, Map.keys(@non_embedded_types), empty_values: [])
    |> cast_embed(:sourceQueryParams)
    |> cast_embed(:sourceHeaders)
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:contactEmail, @email_regex)
    |> validate_format(:orgName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_inclusion(:benefitRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_inclusion(:riskRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_top_level_selector()
    |> validate_schema()
    |> validate_source_query_params()
    |> validate_source_headers()
  end

  def full_validation_changeset(changes), do: full_validation_changeset(%{}, changes)

  def full_validation_changeset(schema, changes) do
    light_validation_changeset(schema, changes) |> validate_unique_system_name()
  end

  def add_source_query_param(changeset, %{} = param \\ %{}) do
    new_key_value_changeset = KeyValue.changeset(%KeyValue{}, param)

    change =
      case fetch_change(changeset, :sourceQueryParams) do
        {:ok, params} -> params ++ [new_key_value_changeset]
        _ -> [new_key_value_changeset]
      end

    put_change(changeset, :sourceQueryParams, change)
  end

  def remove_source_query_param(changeset, id) do
    update_change(changeset, :sourceQueryParams, fn params ->
      Enum.filter(params, fn param -> param.changes.id != id end)
    end)
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

  #TODO: dry up
  defp validate_source_query_params(%{ changes: %{sourceQueryParams: key_values}} = changeset) do
    invalid = Enum.any?(key_values, fn key_value_changeset -> not key_value_changeset.valid? end)
    if invalid, do: add_error(changeset, :sourceQueryParams, "has invalid format", validation: :format), else: changeset
  end

  defp validate_source_query_params(changeset), do: changeset

  defp validate_source_headers(%{ changes: %{sourceHeaders: key_values}} = changeset) do
    invalid = Enum.any?(key_values, fn key_value_changeset -> not key_value_changeset.valid? end)
    if invalid, do: add_error(changeset, :sourceHeaders, "has invalid format", validation: :format), else: changeset
  end

  defp validate_source_headers(changeset), do: changeset
end
