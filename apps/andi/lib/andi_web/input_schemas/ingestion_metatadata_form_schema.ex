defmodule AndiWeb.InputSchemas.IngestionMetadataFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools

  embedded_schema do
    field(:name, :string)
    field(:sourceFormat, :string)
    field(:targetDataset, :string)
  end

  @cast_fields [
    :name,
    :sourceFormat,
    :targetDataset
  ]

  @required_fields [
    :name,
    :sourceFormat,
    :targetDataset
  ]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
    |> target_dataset_exists()
  end

  def changeset_from_andi_ingestion(ingestion) do
    ingestion = StructTools.to_map(ingestion)

    changeset(ingestion)
  end

  defp target_dataset_exists(changeset) do
    validate_change(changeset, :targetDataset, fn :targetDataset, targetDataset ->
      case Andi.InputSchemas.Datasets.get(targetDataset) do
        nil -> [targetDataset: "Dataset with id: #{targetDataset} does not exist. It may have been deleted."]
        _ -> []
      end
    end)
  end

  @spec changeset_from_form_data(any) :: Ecto.Changeset.t()
  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end
end
