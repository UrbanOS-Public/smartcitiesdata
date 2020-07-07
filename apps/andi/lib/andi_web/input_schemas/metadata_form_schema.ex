defmodule AndiWeb.InputSchemas.MetadataFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.StructTools

  @no_dashes_regex ~r/^[^\-]+$/
  @email_regex ~r/^[\w\_\~\!\$\&\'\(\)\*\+\,\;\=\:.-]+@[\w.-]+\.[\w.-]+?$/
  @ratings Map.keys(Options.ratings())

  schema "metadata" do
    field(:benefitRating, :float)
    field(:contactEmail, :string)
    field(:contactName, :string)
    field(:dataName, :string)
    field(:dataTitle, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:issuedDate, :date)
    field(:keywords, {:array, :string})
    field(:language, :string)
    field(:license, :string)
    field(:modifiedDate, :date)
    field(:orgId, :string)
    field(:orgName, :string)
    field(:publishFrequency, :string)
    field(:riskRating, :float)
    field(:sourceFormat, :string)
    field(:sourceType, :string)
    field(:spatial, :string)
    field(:temporal, :string)
    field(:topLevelSelector, :string)
  end

  use Accessible

  @cast_fields [
    :benefitRating,
    :contactEmail,
    :contactName,
    :dataName,
    :dataTitle,
    :description,
    :homepage,
    :issuedDate,
    :keywords,
    :language,
    :language,
    :license,
    :modifiedDate,
    :orgId,
    :orgName,
    :publishFrequency,
    :riskRating,
    :sourceFormat,
    :sourceType,
    :spatial,
    :temporal,
    :topLevelSelector
  ]

  @required_fields [
    :benefitRating,
    :contactEmail,
    :contactName,
    :dataName,
    :dataTitle,
    :description,
    :issuedDate,
    :language,
    :license,
    :orgId,
    :orgName,
    :publishFrequency,
    :riskRating,
    :sourceFormat,
    :sourceType
  ]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(metadata, changes) do
    metadata
    |> cast(changes, @cast_fields)
    |> validate_required(@required_fields, message: "is required")
    |> validate_source_format()
    |> validate_top_level_selector()
    |> validate_format(:dataName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_format(:orgName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_format(:contactEmail, @email_regex)
    |> validate_inclusion(:benefitRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_inclusion(:riskRating, @ratings, message: "should be one of #{inspect(@ratings)}")
  end

  def changeset_for_draft(metadata, changes) do
    cast(metadata, changes, @cast_fields)
  end

  def changeset_from_andi_dataset(dataset) do
    dataset = StructTools.to_map(dataset)
    business_changes = dataset.business
    technical_changes = dataset.technical
    changes = Map.merge(business_changes, technical_changes)

    changeset(changes)
  end

  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end

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
end
