defmodule IngestionHelpers do
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  alias DatasetHelpers

  def create_with_auth_extract_step(context) do
    create_ingestion(%{extractSteps: [%{type: "auth", context: context}]})
  end

  def create_with_http_extract_step(context) do
    create_ingestion(%{extractSteps: [%{type: "http", context: context}]})
  end

  def create_ingestion(overrides) do
    {:ok, dataset} = TDG.create_dataset(%{}) |> Datasets.update()

    smrt_ingestion = overrides |> Map.merge(%{targetDataset: dataset.id}) |> TDG.create_ingestion()
    {:ok, saved_ingestion} = smrt_ingestion |> InputConverter.smrt_ingestion_to_draft_changeset() |> Ingestions.save()

    saved_ingestion
  end

  def get_extract_step_id(ingestion, index) do
    ingestion
    |> Andi.InputSchemas.StructTools.to_map()
    |> Map.get(:extractSteps)
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
