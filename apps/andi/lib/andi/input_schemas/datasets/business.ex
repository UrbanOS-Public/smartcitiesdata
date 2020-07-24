defmodule Andi.InputSchemas.Datasets.Business do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias AndiWeb.Views.Options
  alias Andi.InputSchemas.StructTools

  @email_regex ~r/^[\w\_\~\!\$\&\'\(\)\*\+\,\;\=\:.-]+@[\w.-]+\.[\w.-]+?$/
  @ratings Map.keys(Options.ratings())

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "business" do
    field(:benefitRating, :float)
    field(:contactEmail, :string)
    field(:contactName, :string)
    field(:dataTitle, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:issuedDate, :date)
    field(:keywords, {:array, :string})
    field(:language, :string)
    field(:license, :string)
    field(:modifiedDate, :date)
    field(:orgTitle, :string)
    field(:publishFrequency, :string)
    field(:riskRating, :float)
    field(:spatial, :string)
    field(:temporal, :string)
    field(:rights, :string)

    belongs_to(:dataset, Andi.InputSchemas.Datasets.Dataset, type: :string, foreign_key: :dataset_id)
  end

  use Accessible

  @cast_fields [
    :id,
    :benefitRating,
    :contactEmail,
    :contactName,
    :dataTitle,
    :description,
    :homepage,
    :issuedDate,
    :keywords,
    :language,
    :license,
    :modifiedDate,
    :orgTitle,
    :publishFrequency,
    :riskRating,
    :spatial,
    :temporal,
    :rights
  ]

  @required_fields [
    :benefitRating,
    :contactEmail,
    :contactName,
    :dataTitle,
    :description,
    :issuedDate,
    :license,
    :orgTitle,
    :publishFrequency,
    :riskRating
  ]

  def changeset(business, %_struct{} = changes), do: changeset(business, Map.from_struct(changes))

  def changeset(business, changes) do
    common_changeset_operations(business, changes)
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:contactEmail, @email_regex)
    |> validate_inclusion(:benefitRating, @ratings, message: "should be one of #{inspect(@ratings)}")
    |> validate_inclusion(:riskRating, @ratings, message: "should be one of #{inspect(@ratings)}")
  end

  def changeset_for_draft(business, %_struct{} = changes) do
    changeset_for_draft(business, Map.from_struct(changes))
  end

  def changeset_for_draft(business, changes) do
    common_changeset_operations(business, changes)
  end

  defp common_changeset_operations(business, changes) do
    changes_with_id = StructTools.ensure_id(business, changes)

    business
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> foreign_key_constraint(:dataset_id)
  end

  def preload(struct), do: struct
end
