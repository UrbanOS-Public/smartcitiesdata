defmodule AndiWeb.Unit.IngestionLiveView.IngestionMetadataModelTest do
  use ExUnit.Case
  alias AndiWeb.IngestionLiveView.MetadataModel

  describe "Ingestion Metadata Model" do
    test "can be created with default values" do
      ingestion_model = %MetadataModel{}

      assert ingestion_model.name == ""
      assert ingestion_model.sourceFormat == ""
      assert ingestion_model.targetDataset == ""
      assert ingestion_model.topLevelSelector == ""
    end

    test "can be created with initial values" do
      ingestion_model = %MetadataModel{
        name: "foo",
        sourceFormat: "bar",
        targetDataset: "baz",
        topLevelSelector: "bazoo",
      }

      assert ingestion_model.name == "foo"
      assert ingestion_model.sourceFormat == "bar"
      assert ingestion_model.targetDataset == "baz"
      assert ingestion_model.topLevelSelector == "bazoo"
    end

    test "can merge into a socket" do
      ingestion_model = %MetadataModel{
        name: "apple",
        sourceFormat: "banana",
        targetDataset: "orange",
        topLevelSelector: "pear",
      }

      socket = %Phoenix.LiveView.Socket{}

      result = MetadataModel.merge_to_socket(ingestion_model, socket)

      assert result.assigns.ingestion_model.name == "apple"
      assert result.assigns.ingestion_model.sourceFormat == "banana"
      assert result.assigns.ingestion_model.targetDataset == "orange"
      assert result.assigns.ingestion_model.topLevelSelector == "pear"
  end
end
end
