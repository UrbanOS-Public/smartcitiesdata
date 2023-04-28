defmodule AndiWeb.InputSchemas.IngestionMetadataFormSchema do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  embedded_schema do
    field(:name, :string)
    field(:sourceFormat, :string)
    field(:targetDatasets, {:array, :string})
    field(:topLevelSelector, :string)
  end

  @cast_fields [
    :name,
    :sourceFormat,
    :targetDatasets,
    :topLevelSelector
  ]

  @required_fields [
    :name,
    :sourceFormat,
    :targetDatasets
  ]

  def extract_from_ingestion_changeset(%Ecto.Changeset{data: %Andi.InputSchemas.Ingestion{}} = ingestion_changeset) do
    ingestion_data =
      ingestion_changeset
      |> Changeset.apply_changes()

    extracted_data = %__MODULE__{
      name: ingestion_data.name,
      sourceFormat: ingestion_data.sourceFormat,
      targetDatasets: ingestion_data.targetDatasets,
      topLevelSelector: ingestion_data.topLevelSelector
    }

    mapped_errors =
      ingestion_changeset.errors
      |> Enum.map(fn
        {:name, {msg, opts}} -> {:name, {msg, opts}}
        {:sourceFormat, {msg, opts}} -> {:sourceFormat, {msg, opts}}
        {:topLevelSelector, {msg, opts}} -> {:topLevelSelector, {msg, opts}}
        {:targetDatasets, {msg, opts}} -> {:targetDatasets, {msg, opts}}
        other_errors -> nil
      end)
      |> Enum.reject(&is_nil/1)

    changeset(extracted_data, %{})
    |> Map.put(:errors, mapped_errors)
    |> Map.put(:action, :display_errors)
  end

  def changeset(current, changes) do
    current
    |> Changeset.cast(changes, @cast_fields, empty_values: [])
  end
end
