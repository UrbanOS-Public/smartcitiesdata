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
  alias Andi.InputSchemas.Datasets.ExtractStep
  alias Crontab.CronExpression
  alias AndiWeb.Views.Options

  @no_dashes_regex ~r/^[^\-]+$/
  @invalid_seconds ["*", "*/1", "*/2", "*/3", "*/4", "*/5", "*/6", "*/7", "*/8", "*/9"]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "technical" do
    field(:allow_duplicates, :boolean)
    field(:authBody, :map)
    field(:authBodyEncodeMethod, :string)
    field(:authHeaders, :map)
    field(:authUrl, :string)
    field(:cadence, :string)
    field(:credentials, :boolean)
    field(:dataName, :string)
    field(:orgId, :string)
    field(:orgName, :string)
    field(:private, :boolean)
    field(:protocol, {:array, :string})
    field(:sourceFormat, :string)
    field(:sourceType, :string)
    field(:sourceUrl, :string)
    field(:systemName, :string)
    field(:topLevelSelector, :string)
    has_many(:schema, DataDictionary, on_replace: :delete)
    has_many(:sourceHeaders, Header, on_replace: :delete)
    has_many(:sourceQueryParams, QueryParam, on_replace: :delete)
    has_many(:extractSteps, ExtractStep, on_replace: :delete)

    belongs_to(:dataset, Dataset, type: :string, foreign_key: :dataset_id)
  end

  use Accessible

  @cast_fields [
    :allow_duplicates,
    :authBody,
    :authBodyEncodeMethod,
    :authHeaders,
    :authUrl,
    :cadence,
    :credentials,
    :dataName,
    :id,
    :orgId,
    :orgName,
    :private,
    :protocol,
    :sourceFormat,
    :sourceType,
    :sourceUrl,
    :systemName,
    :topLevelSelector
  ]
  @required_fields [
    :dataName,
    :orgName,
    :private,
    :sourceFormat,
    :sourceType,
    :sourceUrl
  ]

  @submission_cast_fields [
    :dataName,
    :sourceFormat
  ]

  @submission_required_fields [
    :dataName,
    :sourceFormat
  ]

  def changeset(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)
    source_format = Map.get(changes, :sourceFormat, nil)

    technical
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2, source_format), invalid_message: "is required")
    |> cast_assoc(:sourceHeaders, with: &Header.changeset/2)
    |> cast_assoc(:sourceQueryParams, with: &QueryParam.changeset/2)
    |> cast_assoc(:extractSteps, with: &ExtractStep.changeset/2)
    |> foreign_key_constraint(:dataset_id)
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:orgName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_source_format()
    |> validate_cadence()
    |> validate_top_level_selector()
    |> validate_schema()
    |> validate_key_value_parameters()
    |> validate_extract_steps()
  end

  def submission_changeset(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)
    source_format = Map.get(changes, :sourceFormat, nil)

    technical
    |> cast(changes_with_id, @submission_cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset(&1, &2, source_format), invalid_message: "is required")
    |> foreign_key_constraint(:dataset_id)
    |> validate_required(@submission_required_fields, message: "is required")
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_source_format()
    |> validate_submission_schema()
  end

  def changeset_for_draft(technical, changes) do
    changes_with_id = StructTools.ensure_id(technical, changes)

    technical
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:schema, with: &DataDictionary.changeset_for_draft/2)
    |> cast_assoc(:sourceHeaders, with: &Header.changeset_for_draft/2)
    |> cast_assoc(:sourceQueryParams, with: &QueryParam.changeset_for_draft/2)
    |> cast_assoc(:extractSteps, with: &ExtractStep.changeset_for_draft/2)
    |> foreign_key_constraint(:dataset_id)
  end

  def preload(struct), do: StructTools.preload(struct, [:schema, :sourceQueryParams, :sourceHeaders, :extractSteps])

  defp validate_source_format(%{changes: %{sourceType: source_type, sourceFormat: source_format}} = changeset)
       when source_type in ["ingest", "stream"] do
    format_values = Options.source_format() |> Map.new() |> Map.values()

    if source_format in format_values do
      changeset
    else
      add_error(changeset, :sourceFormat, "invalid format for ingestion")
    end
  end

  defp validate_source_format(changeset), do: changeset

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

  defp validate_schema(%{changes: %{sourceType: source_type}} = changeset)
       when source_type in ["ingest", "stream"] do
    case Ecto.Changeset.get_field(changeset, :schema, nil) do
      [] -> add_error(changeset, :schema, "cannot be empty")
      nil -> add_error(changeset, :schema, "is required", validation: :required)
      _ -> validate_schema_internals(changeset)
    end
  end

  defp validate_schema(changeset), do: changeset

  defp validate_submission_schema(%{changes: %{schema: schema}} = changeset) do
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

  defp validate_cadence(%{changes: %{cadence: "once"}} = changeset), do: changeset
  defp validate_cadence(%{changes: %{cadence: "never"}} = changeset), do: changeset

  defp validate_cadence(%{changes: %{cadence: crontab}} = changeset) do
    case validate_cron(crontab) do
      {:ok, _} -> changeset
      {:error, error_msg} -> add_error(changeset, :cadence, "#{error_msg}")
    end
  end

  defp validate_cadence(changeset), do: changeset

  defp validate_cron(crontab) do
    crontab_list = String.split(crontab, " ")

    cond do
      Enum.count(crontab_list) not in [5, 6] ->
        {:error, "Invalid length"}

      Enum.count(crontab_list) == 6 and hd(crontab_list) in @invalid_seconds ->
        {:error, "Cron schedule has a minimum interval of every 10 seconds"}

      true ->
        CronExpression.Parser.parse(crontab, true)
    end
  end

  defp validate_extract_steps(%{changes: %{sourceType: "remote"}} = changeset), do: changeset

  defp validate_extract_steps(changeset) do
    extract_steps = get_field(changeset, :extractSteps)

    case extract_steps in [nil, []] or has_no_http_steps?(extract_steps) do
      true -> add_error(changeset, :extractSteps, "cannot be empty and require at least one http step")
      false -> changeset
    end
  end

  defp has_no_http_steps?(extract_steps), do: Enum.all?(extract_steps, fn step -> step.type != "http" end)

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
