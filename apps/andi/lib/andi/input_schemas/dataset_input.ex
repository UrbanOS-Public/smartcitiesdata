defmodule Andi.InputSchemas.DatasetInput do
  @moduledoc """
  Module for validating Ecto.Changesets on flattened dataset input.
  """
  import Ecto.Changeset

  alias Andi.Services.DatasetRetrieval
  alias Andi.InputSchemas.DatasetSchemaValidator
  alias Andi.InputSchemas.DisplayNames

  @business_fields %{
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
    spatial: :string,
    temporal: :string
  }

  @technical_fields %{
    dataName: :string,
    orgName: :string,
    private: :boolean,
    schema: {:array, :map},
    sourceFormat: :string,
    sourceType: :string,
    topLevelSelector: :string
  }

  @types %{id: :string}
         |> Map.merge(@business_fields)
         |> Map.merge(@technical_fields)

  @required_fields [
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
    :sourceFormat,
    :sourceType
  ]

  @email_regex ~r/^[A-Za-z0-9._%+-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/
  @no_dashes_regex ~r/^[^\-]+$/

  def business_keys(), do: Map.keys(@business_fields)
  def technical_keys(), do: Map.keys(@technical_fields)
  def all_keys(), do: Map.keys(@types)

  def get_display_name(field_key), do: DisplayNames.get(field_key)
  def get_downcased_display_name(field_key), do: field_key |> DisplayNames.get() |> String.downcase()

  def changeset(changes) do
    changeset(%{}, changes)
  end

  def changeset(schema, changes) do
    {schema, @types}
    |> cast(changes, Map.keys(@types), empty_values: [])
    |> validate_required_fields()
    |> validate_format(:contactEmail, @email_regex,
      message: "Please enter a valid #{get_downcased_display_name(:contactEmail)}."
    )
    |> validate_format(:orgName, @no_dashes_regex, message: "#{get_display_name(:orgName)} cannot contain dashes.")
    |> validate_format(:dataName, @no_dashes_regex, message: "#{get_display_name(:dataName)} cannot contain dashes.")
    |> validate_unique_system_name()
    |> validate_top_level_selector()
    |> validate_schema()
  end

  defp validate_required_fields(changeset) do
    Enum.reduce(@required_fields, changeset, fn field_key, changeset_acc ->
      validate_required(changeset_acc, [field_key],
        message: "Please enter a valid #{get_downcased_display_name(field_key)}."
      )
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
    DatasetRetrieval.get_all!()
    |> Enum.all?(fn existing_dataset ->
      changes[:orgName] != existing_dataset.technical.orgName ||
        changes[:dataName] != existing_dataset.technical.dataName ||
        changes[:id] == existing_dataset.id
    end)
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format}} = changeset)
       when source_format in ["xml", "text/xml"] do
    validate_required(changeset, [:topLevelSelector],
      message: "Please enter a valid #{get_downcased_display_name(:topLevelSelector)}."
    )
  end

  defp validate_top_level_selector(changeset), do: changeset

  defp validate_schema(%{changes: %{sourceType: source_type}} = changeset)
       when source_type in ["ingest", "stream"] do
    case Map.get(changeset.changes, :schema) do
      [] ->
        add_error(changeset, :schema, "#{get_display_name(:schema)} cannot be empty.")

      nil ->
        add_error(changeset, :schema, "Please enter a valid #{get_downcased_display_name(:schema)}.",
          validation: :required
        )

      _ ->
        validate_schema_internals(changeset)
    end
  end

  defp validate_schema(changeset), do: changeset

  defp validate_schema_internals(%{changes: changes} = changeset) do
    DatasetSchemaValidator.validate(changes[:schema], changes[:sourceFormat])
    |> Enum.reduce(changeset, fn error, changeset_acc -> add_error(changeset_acc, :schema, error) end)
  end
end
