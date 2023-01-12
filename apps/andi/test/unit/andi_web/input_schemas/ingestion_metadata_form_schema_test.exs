defmodule AndiWeb.InputSchemas.IngestionMetadataFormSchemaTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo

  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema
  alias Andi.InputSchemas.Ingestion


  describe "changeset" do
    test "casts all expected fields as changes" do
      expected_name = "some_ingestion"
      expected_source_format = "csv"
      expected_target_dataset = "some_dataset"
      expected_top_level_selector = "some_top_level_selector"
      changes = %{
        name: expected_name,
        sourceFormat: expected_source_format,
        targetDataset: expected_target_dataset,
        topLevelSelector: expected_top_level_selector
      }

      result = IngestionMetadataFormSchema.changeset(%IngestionMetadataFormSchema{}, changes)

      assert result.changes.name == expected_name
      assert result.changes.sourceFormat == expected_source_format
      assert result.changes.targetDataset == expected_target_dataset
      assert result.changes.topLevelSelector == expected_top_level_selector
    end
  end

  describe "extract_from_ingestion_changeset" do
    test "copies all existing ingestion values into schema" do
      expected_name = "some_ingestion"
      expected_source_format = "csv"
      expected_target_dataset = "some_dataset"
      expected_top_level_selector = "some_top_level_selector"
      existing_ingestion = %Ingestion{
        name: expected_name,
        sourceFormat: expected_source_format,
        targetDataset: expected_target_dataset,
        topLevelSelector: expected_top_level_selector
      }
      ingestion_changeset = Ingestion.changeset(existing_ingestion, %{})


      result = IngestionMetadataFormSchema.extract_from_ingestion_changeset(ingestion_changeset)

      assert result.data.name == expected_name
      assert result.data.sourceFormat == expected_source_format
      assert result.data.targetDataset == expected_target_dataset
      assert result.data.topLevelSelector == expected_top_level_selector
    end

    test "copies any changes on the ingestion changeset into schema" do
      expected_name = "some_ingestion"
      expected_source_format = "csv"
      expected_target_dataset = "some_dataset"
      expected_top_level_selector = "some_top_level_selector"
      existing_ingestion = %Ingestion{}
      changes = %{
        name: expected_name,
        sourceFormat: expected_source_format,
        targetDataset: expected_target_dataset,
        topLevelSelector: expected_top_level_selector
      }
      ingestion_changeset = Ingestion.changeset(existing_ingestion, changes)


      result = IngestionMetadataFormSchema.extract_from_ingestion_changeset(ingestion_changeset)

      assert result.data.name == expected_name
      assert result.data.sourceFormat == expected_source_format
      assert result.data.targetDataset == expected_target_dataset
      assert result.data.topLevelSelector == expected_top_level_selector
    end

    test "copies any errors from ingestion changeset into schema" do
      expected_errors = [
        name: {"is required", [validation: :required]},
        sourceFormat: {"is required", [validation: :required]},
        targetDataset: {"is required", [validation: :required]},
        topLevelSelector: {"is required", [validation: :required]}
      ]
      existing_ingestion = %Ingestion{}
      ingestion_changeset = Ingestion.changeset(existing_ingestion, %{})
                            |> Map.put(:errors, expected_errors)

      result = IngestionMetadataFormSchema.extract_from_ingestion_changeset(ingestion_changeset)

      assert result.errors == expected_errors
    end

    test "filters any errors that do not belong to this schema" do
      ingestion_errors = [
        name: {"is required", [validation: :required]},
        sourceFormat: {"is required", [validation: :required]},
        targetDataset: {"is required", [validation: :required]},
        topLevelSelector: {"is required", [validation: :required]},
        notAField: {"is required", [validation: :required]}
      ]
      expected_errors = [
        name: {"is required", [validation: :required]},
        sourceFormat: {"is required", [validation: :required]},
        targetDataset: {"is required", [validation: :required]},
        topLevelSelector: {"is required", [validation: :required]},
      ]
      existing_ingestion = %Ingestion{}
      ingestion_changeset = Ingestion.changeset(existing_ingestion, %{})
                            |> Map.put(:errors, ingestion_errors)

      result = IngestionMetadataFormSchema.extract_from_ingestion_changeset(ingestion_changeset)

      assert result.errors == expected_errors
    end
  end
end
