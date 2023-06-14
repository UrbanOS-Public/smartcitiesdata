defmodule IngestionHelpers do
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.InputConverter
  alias DatasetHelpers

  def create_with_auth_extract_step(context) do
    create_with_step("auth", context)
  end

  def create_with_http_extract_step(context) do
    create_with_step("http", context)
  end

  def create_with_date_extract_step(context) do
    create_with_step("date", context)
  end

  def create_with_secret_extract_step(context) do
    create_with_step("secret", context)
  end

  defp create_with_step(step, context) do
    create_ingestion(%{extractSteps: [%{type: step, context: context}]})
  end

  def create_ingestion(overrides) do
    andi_dataset = DatasetHelpers.create_empty_dataset()
    smrt_ingestion = Map.merge(%{targetDatasets: [andi_dataset.id]}, overrides) |> TDG.create_ingestion()

    ingestion_changes = smrt_ingestion |> InputConverter.prepare_smrt_ingestion_for_casting()

    andi_ingestion =
      Ingestion.changeset_for_draft(%Ingestion{}, ingestion_changes)
      |> Ecto.Changeset.apply_changes()

    %{ingestion: andi_ingestion, dataset: andi_dataset}
  end

  def save_ingestion(%{ingestion: ingestion, dataset: dataset}) do
    dataset |> Datasets.update()
    save_ingestion(%{ingestion: ingestion})
  end

  def save_ingestion(%{ingestion: ingestion}) do
    ingestion |> Ingestions.update()
  end

  def get_extract_step_id(ingestion, index) do
    ingestion
    |> Andi.InputSchemas.StructTools.to_map()
    |> Map.get(:extractSteps)
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
