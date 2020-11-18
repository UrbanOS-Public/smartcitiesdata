defmodule AndiWeb.InputSchemas.SubmissionMetadataFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter

  schema "submission_metadata" do
    field(:contactName, :string)
    field(:dataName, :string)
    field(:dataTitle, :string)
    field(:description, :string)
    field(:homepage, :string)
    field(:keywords, {:array, :string})
    field(:language, :string)
    field(:sourceFormat, :string)
    field(:spatial, :string)
    field(:temporal, :string)
  end

  use Accessible

  @cast_fields [
    :contactName,
    :dataName,
    :dataTitle,
    :description,
    :homepage,
    :keywords,
    :language,
    :sourceFormat,
    :spatial,
    :temporal
  ]

  @required_fields [
    :dataTitle,
    :description,
    :contactName,
    :sourceFormat
  ]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(metadata, changes) do
    metadata
    |> cast(changes, @cast_fields)
    |> validate_required(@required_fields, message: "is required")
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
end
