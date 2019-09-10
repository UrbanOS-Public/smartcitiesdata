defmodule Forklift.Datasets.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.Datasets.{DatasetHandler, DatasetSchema}
  alias Forklift.TopicManager
  alias Forklift.Tables.TableCreator

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

  describe "update_dataset" do
    test "should not create table when sourceType is remote" do
      dataset = FixtureHelper.dataset(id: "id1", technical: %{sourceType: "remote"})

      allow(TableCreator.create_table(any()), return: {:ok, :whatever})
      DatasetHandler.create_table_for_dataset(dataset)
      assert not called?(TableCreator.create_table(any()))
    end

    test "should not create table when sourceType is unknown" do
      dataset = FixtureHelper.dataset(id: "id1", technical: %{sourceType: "unknown"})

      allow(TableCreator.create_table(any()), return: {:ok, :whatever})
      DatasetHandler.create_table_for_dataset(dataset)
      assert not called?(TableCreator.create_table(any()))
    end

    test "should create table when sourceType is ingest" do
      dataset = FixtureHelper.dataset(id: "id1", technical: %{sourceType: "ingest"})

      allow(TableCreator.create_table(any()), return: :ok)
      DatasetHandler.create_table_for_dataset(dataset)
      assert called?(TableCreator.create_table(any()))
    end

    test "should create table when sourceType is stream" do
      dataset = FixtureHelper.dataset(id: "id1", technical: %{sourceType: "stream"})

      allow(TableCreator.create_table(any()), return: :ok)
      DatasetHandler.create_table_for_dataset(dataset)
      assert called?(TableCreator.create_table(any()))
    end
  end
end
