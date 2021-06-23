defmodule Andi.InputSchemas.Datasets.Business do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.StructTools

  @email_regex ~r/^[\w\_\~\!\$\&\'\(\)\*\+\,\;\=\:.-]+@[\w.-]+\.[\w.-]+?$/
  @url_regex ~r|^https?://[^\s/$.?#].[^\s]*$|
  @ratings Map.keys(Options.ratings())

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "business" do
    field(:authorEmail, :string)
    field(:authorName, :string)
    field(:benefitRating, :float)
    field(:categories, {:array, :string})
    field(:conformsToUri, :string)
    field(:contactEmail, :string)
    field(:contactName, :string)
    field(:dataTitle, :string)
    field(:describedByMimeType, :string)
    field(:describedByUrl, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:issuedDate, :date)
    field(:keywords, {:array, :string})
    field(:language, :string)
    field(:license, :string)
    field(:modifiedDate, :date)
    field(:parentDataset, :string)
    field(:publishFrequency, :string)
    field(:referenceUrls, {:array, :string})
    field(:rights, :string)
    field(:riskRating, :float)
    field(:spatial, :string)
    field(:temporal, :string)

    belongs_to(:dataset, Andi.InputSchemas.Datasets.Dataset, type: :string, foreign_key: :dataset_id)
  end

  use Accessible

  @cast_fields [
    :authorEmail,
    :authorName,
    :benefitRating,
    :categories,
    :conformsToUri,
    :contactEmail,
    :contactName,
    :dataTitle,
    :describedByMimeType,
    :describedByUrl,
    :description,
    :homepage,
    :id,
    :issuedDate,
    :keywords,
    :language,
    :license,
    :modifiedDate,
    :parentDataset,
    :publishFrequency,
    :referenceUrls,
    :rights,
    :riskRating,
    :spatial,
    :temporal
  ]

  @required_fields [
    :benefitRating,
    :contactEmail,
    :contactName,
    :dataTitle,
    :description,
    :issuedDate,
    :license,
    :publishFrequency,
    :riskRating
  ]

  @submission_cast_fields [
    :contactName,
    :dataTitle,
    :description,
    :homepage,
    :keywords,
    :language,
    :spatial,
    :temporal
  ]

  @submission_required_fields [
    :dataTitle,
    :description,
    :contactName
  ]

  def changeset(business, %_struct{} = changes), do: changeset(business, Map.from_struct(changes))

  # Validations here are mirrored in lib/andi_web/input_schemas/metadata_form_schema.ex
  def changeset(business, changes) do
    common_changeset_operations(business, changes, @cast_fields)
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:contactEmail, @email_regex)
    |> validate_format(:license, @url_regex, message: "should be a valid url link to the text of the license")
    |> validate_inclusion(:benefitRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_inclusion(:riskRating, @ratings, message: "should be one of #{inspect(@ratings)}")
  end

  def submission_changeset(business, %_struct{} = changes), do: submission_changeset(business, Map.from_struct(changes))

  # Validations here are mirrored in lib/andi_web/input_schemas/metadata_form_schema.ex
  def submission_changeset(business, changes) do
    common_changeset_operations(business, changes, @submission_cast_fields)
    |> validate_required(@submission_required_fields, message: "is required")
  end

  def changeset_for_draft(business, %_struct{} = changes) do
    changeset_for_draft(business, Map.from_struct(changes))
  end

  def changeset_for_draft(business, changes) do
    common_changeset_operations(business, changes, @cast_fields)
  end

  defp common_changeset_operations(business, changes, fields) do
    changes_with_id = StructTools.ensure_id(business, changes)

    business
    |> cast(changes_with_id, fields, empty_values: [])
    |> foreign_key_constraint(:dataset_id)
  end

  def preload(struct), do: struct
end
