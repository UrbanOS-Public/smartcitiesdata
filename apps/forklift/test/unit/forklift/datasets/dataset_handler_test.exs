defmodule Forklift.Datasets.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.Datasets.{DatasetHandler, DatasetSchema}
  alias Forklift.TopicManager

  describe "start_dataset_ingest/1" do
    test "happy path" do
      allow TopicManager.setup_topics(any()), return: %{input_topic: :whatever}
      allow DynamicSupervisor.start_child(Forklift.Dynamic.Supervisor, any()), return: {:ok, :success}
      allow DynamicSupervisor.terminate_child(Forklift.Dynamic.Supervisor, any()), return: {:ok, :killed}

      schema = %DatasetSchema{id: "id", system_name: "system__name", columns: []}

      assert {:ok, :success} = DatasetHandler.start_dataset_ingest(schema)
    end
  end

  describe "stop_dataset_ingest/1" do
    test "returns :ok if no process found" do
      schema = %DatasetSchema{id: "id", system_name: "system__name", columns: []}

      assert :ok = DatasetHandler.stop_dataset_ingest(schema)
    end
  end
end
