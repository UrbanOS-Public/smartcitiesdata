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
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset_for_draft/2)
    |> Changeset.foreign_key_constraint(:targetDataset)
  end

  def changeset(%SmartCity.Ingestion{} = changes) do
    changes_as_map = StructTools.to_map(changes)
    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(%__MODULE__{} = ingestion, %{} = changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)
    source_format = Map.get(changes, :sourceFormat, nil)

    ingestion
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [])
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset_for_draft/2)
  end

  def changeset(%Ecto.Changeset{data: %__MODULE__{}} = changeset, changes) do
    source_format = Map.get(changes, :sourceFormat, nil)

    changeset
    |> Changeset.cast(changes, @cast_fields, empty_values: [])
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset_for_draft/2)
  end

  def changeset_for_draft(%Andi.InputSchemas.Ingestion{} = ingestion, changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)

    ingestion
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [""])
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset_for_draft/2)
  end

  def changeset_for_draft(%Ecto.Changeset{data: %__MODULE__{}} = changeset, changes) do
    changeset
    |> Changeset.cast(changes, @cast_fields, empty_values: [""])
    |> Changeset.cast_assoc(:schema, with: &DataDictionary.changeset_for_draft_ingestion/2)
    |> Changeset.cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> Changeset.cast_assoc(:transformations, with: &Transformation.changeset_for_draft/2)
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
    changeset |> Changeset.fetch_field!(:sourceFormat)
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

  defp validate_schema(changeset) do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
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
    extract_steps = Changeset.get_field(changeset, :extractSteps)

    case extract_steps in [nil, []] or not ExtractStepHelpers.ends_with_http_or_s3_step?(extract_steps) do
      true -> Changeset.add_error(changeset, :extractSteps, "cannot be empty and must end with a http or s3 step")
      false -> changeset
    end
  end
end
