defmodule AndiWeb.InputSchemas.IngestionMetadataFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools

  embedded_schema do
    field(:name, :string)
    field(:sourceFormat, :string)
  end

  @cast_fields [
    :name,
    :sourceFormat
  ]

  @required_fields [
    :name,
    :sourceFormat
  ]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
  end

  def changeset_from_andi_ingestion(ingestion) do
    ingestion = StructTools.to_map(ingestion)

    changeset(ingestion)
  end

  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end
end
