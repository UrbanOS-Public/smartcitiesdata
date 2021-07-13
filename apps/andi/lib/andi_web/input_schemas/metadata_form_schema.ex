defmodule AndiWeb.InputSchemas.MetadataFormSchema do
  @moduledoc false

  use Ecto.Schema
  use Properties, otp_app: :andi

  import Ecto.Changeset

  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter

  getter(:dataset_name_max_length, generic: true)
  getter(:org_name_max_length, generic: true)

  @no_dashes_regex ~r/^[^\-]+$/
  @email_regex ~r/^[\w\_\~\!\$\&\'\(\)\*\+\,\;\=\:.-]+@[\w.-]+\.[\w.-]+?$/
  @url_regex ~r|^https?://[^\s/$.?#].[^\s]*$|
  @ratings Map.keys(Options.ratings())

  schema "metadata" do
    field(:benefitRating, :float)
    field(:contactEmail, :string)
    field(:contactName, :string)
    field(:dataName, :string)
    field(:dataTitle, :string)
    field(:datasetId, :string)
    field(:ownerId, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:issuedDate, :date)
    field(:keywords, {:array, :string})
    field(:language, :string)
    field(:license, :string)
    field(:modifiedDate, :date)
    field(:orgId, :string)
    field(:orgName, :string)
    field(:orgTitle, :string)
    field(:publishFrequency, :string)
    field(:private, :boolean)
    field(:riskRating, :float)
    field(:sourceFormat, :string)
    field(:sourceType, :string)
    field(:spatial, :string)
    field(:systemName, :string)
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
    :datasetId,
    :ownerId,
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
    :orgTitle,
    :private,
    :publishFrequency,
    :riskRating,
    :sourceFormat,
    :sourceType,
    :systemName,
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
    :datasetId,
    :description,
    :issuedDate,
    :language,
    :license,
    :orgId,
    :orgName,
    :orgTitle,
    :private,
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
    |> validate_length(:dataName, max: dataset_name_max_length())
    |> validate_format(:orgName, @no_dashes_regex, message: "cannot contain dashes")
    |> validate_length(:orgName, max: org_name_max_length())
    |> validate_format(:contactEmail, @email_regex)
    |> validate_format(:license, @url_regex, message: "should be a valid url link to the text of the license")
    |> validate_inclusion(:benefitRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_inclusion(:riskRating, @ratings, message: "should be one of #{inspect(@ratings)}")
  end

  def changeset_for_draft(metadata, changes) do
    cast(metadata, changes, @cast_fields)
  end

  def changeset_from_andi_dataset(dataset) do
    owner_id = dataset.owner_id
    dataset = StructTools.to_map(dataset)

    business_changes = dataset.business
    technical_changes = dataset.technical
    changes = Map.merge(business_changes, technical_changes)
    changes = Map.put(changes, :datasetId, dataset.id)
    changes = Map.put_new(changes, :ownerId, owner_id)

    changeset(changes)
  end

  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> InputConverter.fix_modified_date()
    |> Map.update(:keywords, nil, &InputConverter.keywords_to_list/1)
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
