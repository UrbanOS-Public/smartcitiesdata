defmodule Andi.InputSchemas.Ingestion do
  @moduledoc """
  Module for validating Ecto.Changesets on ingestion input
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.Datasets.ExtractStep
  alias Andi.Schemas.Validation.CadenceValidator
  alias AndiWeb.Helpers.ExtractStepHelpers
  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.DatasetSchemaValidator

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "ingestions" do
    field(:allow_duplicates, :boolean)
    field(:cadence, :string)
    field(:sourceFormat, :string)
    field(:topLevelSelector, :string)
    belongs_to(:dataset, Dataset, type: Ecto.UUID, foreign_key: :targetDataset)
    has_many(:schema, DataDictionary, on_replace: :delete)
    has_many(:extractSteps, ExtractStep, on_replace: :delete)
  end

  use Accessible

  @cast_fields [
    :id,
    :cadence,
    :sourceFormat,
    :topLevelSelector,
    :targetDataset
  ]

  @required_fields [
    :cadence,
    :sourceFormat,
    :targetDataset
  ]

  @submission_cast_fields [
    :sourceFormat
  ]

  @submission_required_fields [
    :sourceFormat
  ]

  def changeset(%SmartCity.Ingestion{} = changes) do
    changes_as_map = StructTools.to_map(changes)
    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(ingestion, changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)
    source_format = Map.get(changes, :sourceFormat, nil)
    dataset = Datasets.get(ingestion.targetDataset)
    source_type = dataset.technical.sourceType

    ingestion
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2, source_format), invalid_message: "is required")
    |> cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
    |> foreign_key_constraint(:targetDataset)
    |> validate_source_format(source_type)
    |> CadenceValidator.validate()
    |> validate_top_level_selector()
    |> validate_schema(source_type)
    |> validate_extract_steps(source_type)
  end

  # TODO 549: update for ingestion
  def submission_changeset(ingestion, changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)
    source_format = Map.get(changes, :sourceFormat, nil)

    ingestion
    |> cast(changes_with_id, @submission_cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2, source_format), invalid_message: "is required")
    |> foreign_key_constraint(:targetDataset)
    |> validate_required(@submission_required_fields, message: "is required")
    # |> validate_source_format()
    |> validate_submission_schema()
  end

  def changeset_for_draft(ingestion, changes) do
    changes_with_id = StructTools.ensure_id(ingestion, changes)

    ingestion
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset_for_draft/2)
    |> cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> foreign_key_constraint(:targetDataset)
  end

  def preload(struct), do: StructTools.preload(struct, [:schema, :extractSteps])

  def full_validation_changeset(changes), do: full_validation_changeset(%__MODULE__{}, changes)

  def full_validation_changeset(schema, changes) do
    changeset(schema, changes)
  end

  defp validate_source_format(%{changes: %{sourceFormat: source_format}} = changeset, source_type)
       when source_type in ["ingest", "stream"] do
    format_values = Options.source_format() |> Map.new() |> Map.values()

    if source_format in format_values do
      changeset
    else
      add_error(changeset, :sourceFormat, "invalid format for ingestion")
    end
  end

  defp validate_source_format(changeset, source_type), do: changeset

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format}} = changeset) when source_format in ["xml", "text/xml"] do
    validate_required(changeset, [:topLevelSelector], message: "is required")
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format, topLevelSelector: top_level_selector}} = changeset)
       when source_format in ["json", "application/json"] do
    case Jaxon.Path.parse(top_level_selector) do
      {:error, error_msg} -> add_error(changeset, :topLevelSelector, error_msg.message)
      _ -> changeset
    end
  end

  defp validate_top_level_selector(changeset), do: changeset

  defp validate_schema(changeset, source_type)
       when source_type in ["ingest", "stream"] do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
      [] -> add_error(changeset, :schema, "cannot be empty")
      nil -> add_error(changeset, :schema, "is required", validation: :required)
      _ -> validate_schema_internals(changeset)
    end
  end

  defp validate_schema(changeset, _), do: changeset

  defp validate_submission_schema(%{changes: %{schema: _}} = changeset) do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
      [] -> add_error(changeset, :schema, "cannot be empty")
      nil -> add_error(changeset, :schema, "is required", validation: :required)
      _ -> validate_schema_internals(changeset)
    end
  end

  defp validate_schema_internals(%{changes: changes} = changeset) do
    schema =
      Ecto.Changeset.get_field(changeset, :schema, [])
      |> StructTools.to_map()

    DatasetSchemaValidator.validate(schema, changes[:sourceFormat])
    |> Enum.reduce(changeset, fn error, changeset_acc -> add_error(changeset_acc, :schema, error) end)
  end

  defp validate_extract_steps(changeset, source_type)
       when source_type in ["remote"] do
    changeset
  end

  defp validate_extract_steps(%{changes: %{cadence: "continuous"}} = changeset, _source_type), do: changeset

  defp validate_extract_steps(changeset, _source_type) do
    extract_steps = get_field(changeset, :extractSteps)

    case extract_steps in [nil, []] or not ExtractStepHelpers.ends_with_http_or_s3_step?(extract_steps) do
      true -> add_error(changeset, :extractSteps, "cannot be empty and must end with a http or s3 step")
      false -> changeset
    end
  end
end
