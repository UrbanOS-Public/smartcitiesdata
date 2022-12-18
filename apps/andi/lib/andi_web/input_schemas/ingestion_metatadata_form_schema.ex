defmodule AndiWeb.InputSchemas.IngestionMetadataFormSchema do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  embedded_schema do
    field(:name, :string)
    field(:sourceFormat, :string)
    field(:targetDataset, :string)
    field(:topLevelSelector, :string)
  end

  @cast_fields [
    :name,
    :sourceFormat,
    :targetDataset,
    :topLevelSelector
  ]

  @required_fields [
    :name,
    :sourceFormat,
    :targetDataset
  ]

  def merge_to_ingestion_changeset(%Ecto.Changeset{ data: %Andi.InputSchemas.Ingestion{} } = ingestion_changeset, form_data) do
    changeset(ingestion_changeset, form_data)
  end


  def extract_from_ingestion_changeset(%Ecto.Changeset{ data: %Andi.InputSchemas.Ingestion{} } = ingestion_changeset) do
    ingestion_data = ingestion_changeset
    |> Changeset.apply_changes

    extracted_data = %{
      name: ingestion_data.name,
      sourceFormat: ingestion_data.sourceFormat,
      targetDataset: ingestion_data.targetDataset,
      topLevelSelector: ingestion_data.topLevelSelector
    }

    changeset(extracted_data)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(current, changes) do
    current
    |> Changeset.cast(changes, @cast_fields, empty_values: [])
    |> Changeset.validate_required(@required_fields, message: "is required")
    |> validate_top_level_selector()
    |> target_dataset_exists()
    |> Map.put(:action, :update)
  end

  def changeset_from_andi_ingestion(ingestion) do
    ingestion = StructTools.to_map(ingestion)

    changeset(ingestion)
  end

  defp target_dataset_exists(changeset) do
    Changeset.validate_change(changeset, :targetDataset, fn :targetDataset, targetDataset ->
      case Andi.InputSchemas.Datasets.get(targetDataset) do
        nil ->
          [
            targetDataset: "Dataset with id: #{targetDataset} does not exist. It may have been deleted."
          ]

        _ ->
          []
      end
    end)
  end

  @spec changeset_from_form_data(any) :: Ecto.Changeset.t()
  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format}} = changeset)
       when source_format in ["xml", "text/xml"] do
    Changeset.validate_required(changeset, [:topLevelSelector], message: "is required")
  end

  defp validate_top_level_selector(%{changes: %{sourceFormat: source_format, topLevelSelector: top_level_selector}} = changeset)
       when source_format in ["json", "application/json"] do
    case Jaxon.Path.parse(top_level_selector) do
      {:error, error_msg} -> Changeset.add_error(changeset, :topLevelSelector, error_msg.message)
      _ -> changeset
    end
  end

  defp validate_top_level_selector(changeset), do: changeset
end
