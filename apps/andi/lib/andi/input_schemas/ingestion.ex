defmodule Andi.InputSchemas.Ingestion do
  @moduledoc """
  Module for validating Ecto.Changesets on ingestion input
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.Ingestions.ExtractStep
  alias Andi.Schemas.Validation.CadenceValidator
  alias AndiWeb.Helpers.ExtractStepHelpers
  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.DatasetSchemaValidator
  alias Andi.InputSchemas.Ingestions.Transformation

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "ingestions" do
    field(:allow_duplicates, :boolean)
    field(:name, :string)
    field(:cadence, :string)
    field(:sourceFormat, :string)
    field(:topLevelSelector, :string)
    field(:submissionStatus, Ecto.Enum, values: [:published, :draft], default: :draft)
    belongs_to(:dataset, Dataset, type: :string, foreign_key: :targetDataset)
    has_many(:schema, DataDictionary, on_replace: :delete)
    has_many(:extractSteps, ExtractStep, on_replace: :delete)
    has_many(:transformations, Transformation, on_replace: :delete)
  end

  use Accessible

  @cast_fields [
    :id,
    :cadence,
    :sourceFormat,
    :topLevelSelector,
    :targetDataset,
    :name,
    :sourceFormat,
    :submissionStatus
  ]

  @required_fields [
    :cadence,
    :sourceFormat,
    :targetDataset,
    :name
  ]

  def validate(%Ecto.Changeset{data: %__MODULE__{}} = changeset) do
    data_as_changes =
      changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    source_format = Map.get(data_as_changes, :sourceFormat, nil)

    changeset
    |> Map.replace(:errors, [])
    |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2, source_format), invalid_message: "is required")
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset/2)
    |> Changeset.validate_required(@required_fields, message: "is required")
    |> Changeset.foreign_key_constraint(:targetDataset)
    |> validate_source_format()
    |> CadenceValidator.validate()
    |> validate_top_level_selector()
    |> validate_schema()
    |> validate_extract_steps()
    |> validate_transformations()
  end

  def validate_database_safety(%Ecto.Changeset{data: %__MODULE__{}} = changeset) do
    data_as_changes =
      changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    source_format = Map.get(data_as_changes, :sourceFormat, nil)

    changeset
    |> Map.replace(:errors, [])
    |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset/2)
    |> Changeset.foreign_key_constraint(:targetDataset)
  end

  def changeset(%SmartCity.Ingestion{} = changes) do
    changes_as_map = StructTools.to_map(changes)
    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(%__MODULE__{} = ingestion, %{} = changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)

    new_ingestion =
      ingestion
      |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [])
      |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
      |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
      |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset/2)
  end

  def changeset(%Ecto.Changeset{data: %__MODULE__{}} = changeset, changes) do
    new_changeset =
      changeset
      |> Changeset.cast(changes, @cast_fields, empty_values: [])
      |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
      |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
      |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset/2)
  end

  def changeset_for_draft(%Andi.InputSchemas.Ingestion{} = ingestion, changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)

    ingestion
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [""])
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset/2)
  end

  def changeset_for_draft(%Ecto.Changeset{data: %__MODULE__{}} = changeset, changes) do
    changeset
    |> Changeset.cast(changes, @cast_fields, empty_values: [""])
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset/2)
  end

  def merge_metadata_changeset(
        %Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset,
        %Ecto.Changeset{data: %AndiWeb.InputSchemas.IngestionMetadataFormSchema{}} = metadata_changeset
      ) do
    metadata =
      metadata_changeset
      |> Changeset.apply_changes()

    extracted_metadata = %{
      name: metadata.name,
      sourceFormat: metadata.sourceFormat,
      topLevelSelector: metadata.topLevelSelector,
      targetDataset: metadata.targetDataset
    }

    changeset(ingestion_changeset, extracted_metadata)
  end

  def merge_extract_step_changeset(
        %Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset,
        extract_step_changesets
      ) do
    extract_step_changeset_list =
      Enum.reduce(extract_step_changesets, [], fn extract_step_changeset, acc ->
        extract_step_changes = StructTools.to_map(Changeset.apply_changes(extract_step_changeset))
        [extract_step_changes | acc]
      end)

    cleared_ingestion_changeset = Changeset.delete_change(ingestion_changeset, :extractSteps)

    changeset(cleared_ingestion_changeset, %{extractSteps: extract_step_changeset_list})
  end

  def merge_data_dictionary(
        %Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset,
        schema_changeset
      ) do
    schema =
      case Changeset.fetch_field(schema_changeset, :schema) do
        {_, schema} -> schema
        :error -> []
      end
      |> Enum.reduce([], fn schema, acc ->
        data_dictionary_schema = map_schema(schema)

        [data_dictionary_schema | acc]
      end)

    cleared_ingestion_changeset = Changeset.delete_change(ingestion_changeset, :schema)

    changeset(cleared_ingestion_changeset, %{schema: schema})
  end

  defp map_schema(schema) do
    updated_schema = StructTools.to_map(schema)
    |> Map.put_new(:name, "")
    |> Map.put_new(:type, "")
    |> Map.put_new(:subSchema, [])

    updated_sub_schema = updated_schema
      |> Map.get(:subSchema, [])
      |> Enum.map(fn subSchema -> map_schema(subSchema) end)

    Map.put(updated_schema, :subSchema, updated_sub_schema)
  end

  def merge_finalize_changeset(
        %Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset,
        %Ecto.Changeset{data: %AndiWeb.InputSchemas.FinalizeFormSchema{}} = finalize_changeset
      ) do
    finalize =
      finalize_changeset
      |> Changeset.apply_changes()

    extracted_finalize = %{
      cadence: finalize.cadence
    }

    changeset(ingestion_changeset, extracted_finalize)
  end

  def get_extract_step_changesets_and_errors(ingestion_changeset) do
    extract_step_changesets =
      case Changeset.fetch_change(ingestion_changeset, :extractSteps) do
        {_, extract_steps} -> extract_steps
        :error -> []
      end

    {_, {extract_step_errors, _}} =
      Enum.find(Map.get(ingestion_changeset, :errors, []), {"", {"", ""}}, fn {property, _message} -> property == :extractSteps end)

    {extract_step_changesets, extract_step_errors}
  end

  def merge_transformation_changeset(%Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset, transformation_changesets) do
    transformation_changeset_list =
      Enum.reduce(transformation_changesets, [], fn transformation_changeset, acc ->
        transformation_changes = StructTools.to_map(Changeset.apply_changes(transformation_changeset))
        [transformation_changes | acc]
      end)

    cleared_ingestion_changeset = Changeset.delete_change(ingestion_changeset, :transformations)

    changeset(cleared_ingestion_changeset, %{transformations: transformation_changeset_list})
  end

  def get_transformation_changesets(ingestion_changeset) do
    transformations =
      case Changeset.fetch_change(ingestion_changeset, :transformations) do
        {_, transformations} -> transformations
        :error -> []
      end

    Enum.reduce(transformations, [], fn transformation, acc ->
      [Transformation.validate(transformation) | acc]
    end)
    |> Enum.reverse()
  end

  @spec preload(nil | maybe_improper_list | struct) :: any
  def preload(struct), do: StructTools.preload(struct, [:schema, :extractSteps, :transformations])

  defp validate_source_format(%{changes: %{sourceFormat: source_format}} = changeset) do
    format_values = Options.source_format() |> Map.new() |> Map.values()

    if source_format in format_values do
      changeset
    else
      Changeset.add_error(changeset, :sourceFormat, "invalid format for ingestion")
    end
  end

  defp validate_source_format(changeset) do
    Changeset.validate_required(changeset, [:sourceFormat], message: "is required")
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format}} = changeset) when source_format in ["xml", "text/xml"] do
    Changeset.validate_required(changeset, [:topLevelSelector], message: "is required")
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format, topLevelSelector: top_level_selector}} = changeset)
       when source_format in ["json", "application/json"] do
    case Jaxon.Path.parse(top_level_selector) do
      {:error, error_msg} -> Changeset.add_error(changeset, :topLevelSelector, error_msg.message)
      _ -> changeset
    end
  end

  defp validate_top_level_selector(changeset), do: changeset

  def validate_schema(changeset) do
    case Changeset.get_field(changeset, :schema, nil) do
      [] -> Changeset.add_error(changeset, :schema, "cannot be empty")
      nil -> Changeset.add_error(changeset, :schema, "is required", validation: :required)
      _ -> validate_schema_internals(changeset)
    end
  end

  defp validate_schema_internals(%{changes: changes} = changeset) do
    schema =
      Changeset.get_field(changeset, :schema, [])
      |> StructTools.to_map()

    DatasetSchemaValidator.validate(schema, changes[:sourceFormat])
    |> Enum.reduce(changeset, fn error, changeset_acc -> Changeset.add_error(changeset_acc, :schema, error) end)
  end

  defp validate_extract_steps(changeset) do
    extract_steps =
      Changeset.get_field(changeset, :extractSteps)
      |> StructTools.sort_if_sequenced()

    changeset =
      case extract_steps in [nil, []] or not ExtractStepHelpers.ends_with_http_or_s3_step?(extract_steps) do
        true -> Changeset.add_error(changeset, :extractSteps, "Cannot be empty and must end with a http or s3 step")
        false -> changeset
      end

    Enum.reduce(extract_steps, changeset, fn extract_step, acc ->
      case ExtractStep.step_module(extract_step.type) == :invalid_type do
        true -> Changeset.add_error(acc, :extract_step_type, "invalid type")
        false -> acc
      end

      validate_context(extract_step, acc)
    end)
  end

  defp validate_context(extract_step, changeset) do
    case ExtractStep.step_module(extract_step.type) do
      :invalid_type ->
        changeset

      nil ->
        changeset

      step_module ->
        if is_nil(extract_step.context) do
          Changeset.add_error(changeset, :extract_step_context, "invalid context")
        else
          validated_changeset =
            step_module.changeset(step_module.get_module(), extract_step.context)
            |> step_module.validate()

          Enum.reduce(validated_changeset.errors, changeset, fn {key, {message, _}}, acc ->
            Changeset.add_error(acc, key, message)
          end)
        end
    end
  end

  defp validate_transformations(changeset) do
    transformations = Changeset.get_field(changeset, :transformations)

    Enum.reduce(transformations, changeset, fn transformation, acc ->
      validated_changeset =
        Transformation.changeset(Transformation.get_module(), StructTools.to_map(transformation))
        |> Transformation.validate()

      Enum.reduce(validated_changeset.errors, acc, fn {key, {message, _}}, acc_error ->
        Changeset.add_error(acc_error, key, message)
      end)
    end)
  end
end
