defmodule AndiWeb.InputSchemas.IngestionMetadataFormSchemaTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo

  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema

  describe "changeset_from_form_data()" do
    test "generates a valid changeset when all data is present" do
      form_data = %{
        sourceFormat: "csv",
        name: "Ingestion Name",
        targetDataset: "dataset_id"
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})
      changeset = IngestionMetadataFormSchema.changeset_from_form_data(form_data)

      assert changeset.valid?
    end

    test "generates a changeset with errors when sourceFormat is absent" do
      form_data = %{
        name: "Ingestion Name",
        targetDataset: "Dataset Name"
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})

      changeset = IngestionMetadataFormSchema.changeset_from_form_data(form_data)

      refute changeset.valid?
      assert changeset.errors == [{:sourceFormat, {"is required", [validation: :required]}}]
    end

    test "generates a changeset with errors when ingestion name is absent" do
      form_data = %{
        sourceFormat: "csv",
        targetDataset: "Dataset Name"
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})

      changeset = IngestionMetadataFormSchema.changeset_from_form_data(form_data)

      refute changeset.valid?
      assert changeset.errors == [{:name, {"is required", [validation: :required]}}]
    end

    test "displays error when topLevelSelector json Jaxon validation is invalid" do
      badJsonPath = "$.data[x]"

      form_data = %{
        sourceFormat: "application/json",
        targetDataset: "Dataset Name",
        name: "ingestion123",
        topLevelSelector: badJsonPath
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})
      changeset = IngestionMetadataFormSchema.changeset_from_form_data(form_data)
      refute changeset.valid?
      assert changeset.errors == [{:topLevelSelector, {"Expected an integer at `x]`", []}}]
    end

    test "generates a changeset with errors when targetDataset is absent" do
      form_data = %{
        sourceFormat: "csv",
        name: "Ingestion Name"
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})

      changeset = IngestionMetadataFormSchema.changeset_from_form_data(form_data)

      refute changeset.valid?
      assert changeset.errors == [{:targetDataset, {"is required", [validation: :required]}}]
    end

    test "generates a changeset with errors when targetDataset id does not exist in ANDI database" do
      form_data = %{
        sourceFormat: "csv",
        targetDataset: "dataset_id",
        name: "Ingestion Name"
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: nil)

      changeset = IngestionMetadataFormSchema.changeset_from_form_data(form_data)

      refute changeset.valid?
      assert changeset.errors == [targetDataset: {"Dataset with id: dataset_id does not exist. It may have been deleted.", []}]
    end
  end

  describe "changeset_from_andi_ingestion()" do
    test "generates a valid changeset when all data is present" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        name: "ingestion name",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})
      changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)

      assert changeset.valid?
    end

    test "generates a changeset with errors when sourceFormat is absent" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        name: "ingestion name",
        targetDataset: "dataset_id",
        cadence: "once",
        extractSteps: [],
        schema: []
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})

      changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)

      refute changeset.valid?
      assert changeset.errors == [{:sourceFormat, {"is required", [validation: :required]}}]
    end

    test "generates a changeset with errors when ingestion name is absent" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: %{id: "dataset_id"})

      changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)

      refute changeset.valid?
      assert changeset.errors == [{:name, {"is required", [validation: :required]}}]
    end

    test "generates a changeset with errors when targetDataset is absent" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        name: "ingestion name",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: nil)

      changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)

      refute changeset.valid?
      assert changeset.errors == [{:targetDataset, {"is required", [validation: :required]}}]
    end

    test "generates a changeset with errors when targetDataset id does not exist in ANDI database" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        name: "ingestion name",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.InputSchemas.Datasets.get(any()), return: nil)

      changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)

      refute changeset.valid?
      assert changeset.errors == [targetDataset: {"Dataset with id: dataset_id does not exist. It may have been deleted.", []}]
    end
  end
end
