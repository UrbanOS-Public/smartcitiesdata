defmodule Andi.InputSchemas.Datasets.DataDictionary do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "data_dictionary" do
    field(:name, :string)
    field(:type, :string)
    field(:itemType, :string)
    field(:selector, :string)
    field(:biased, :string)
    field(:demographic, :string)
    field(:description, :string, description: "")
    field(:masked, :string)
    field(:pii, :string)
    field(:rationale, :string)
    field(:bread_crumb, :string)
    has_many(:subSchema, __MODULE__, foreign_key: :parent_id, on_replace: :delete)

    belongs_to(:data_dictionary, __MODULE__, type: Ecto.UUID, foreign_key: :parent_id)
    belongs_to(:technical, Technical, type: Ecto.UUID, foreign_key: :technical_id)
    belongs_to(:dataset, Dataset, type: :string, foreign_key: :dataset_id)
  end

  use Accessible

  @cast_fields [
    :id,
    :name,
    :type,
    :selector,
    :itemType,
    :biased,
    :demographic,
    :description,
    :masked,
    :pii,
    :rationale,
    :dataset_id,
    :technical_id,
    :parent_id,
    :bread_crumb
  ]
  @required_fields [
    :name,
    :type,
    :dataset_id,
    :bread_crumb
  ]

  def changeset(dictionary, changes, source_format) do
    changes_with_id = StructTools.ensure_id(dictionary, changes)

    dictionary
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:subSchema, with: &__MODULE__.changeset(&1, &2, source_format))
    |> foreign_key_constraint(:dataset_id)
    |> foreign_key_constraint(:technical_id)
    |> foreign_key_constraint(:parent_id)
    |> validate_required(@required_fields, message: "is required")
    |> validate_item_type()
    |> validate_selector(source_format)
  end

  def changeset_for_new_field(dictionary, changes) do
    changes_with_id = StructTools.ensure_id(dictionary, changes)

    dictionary
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:subSchema, with: &__MODULE__.changeset_for_new_field/2)
    |> foreign_key_constraint(:dataset_id)
    |> foreign_key_constraint(:technical_id)
    |> foreign_key_constraint(:parent_id)
    |> validate_required(@required_fields, message: "is required")
  end

  def changeset_for_draft(dictionary, changes) do
    changes_with_id = StructTools.ensure_id(dictionary, changes)

    dictionary
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:subSchema, with: &__MODULE__.changeset_for_draft/2)
    |> foreign_key_constraint(:dataset_id)
    |> foreign_key_constraint(:technical_id)
    |> foreign_key_constraint(:parent_id)
  end

  def preload(struct), do: StructTools.preload(struct, [:subSchema])

  defp validate_item_type(%{changes: %{type: "list"}} = changeset) do
    validate_required(changeset, [:itemType], message: "is required")
  end

  defp validate_item_type(changeset), do: changeset

  defp validate_selector(changeset, source_format) when source_format in ["xml", "text/xml"] do
    validate_required(changeset, :selector, message: "is required")
  end

  defp validate_selector(changeset, _), do: changeset
end
