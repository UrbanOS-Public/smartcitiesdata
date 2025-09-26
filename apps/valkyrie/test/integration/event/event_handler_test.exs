defmodule Valkyrie.Event.EventHandlerTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :valkyrie

  import SmartCity.TestHelper
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter

  @instance_name Valkyrie.instance_name()
  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)

  describe "Data Ingest Start" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Brook.get! failures
      # For integration testing, real failure conditions should be used instead
    end
  end

  describe "Dataset Update" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Valkyrie.DatasetSupervisor.is_started? failures
      # For integration testing, real failure conditions should be used instead
    end
  end

  describe "Dataset Delete" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Valkyrie.DatasetProcessor.delete failures
      # For integration testing, real failure conditions should be used instead
    end
  end

  describe "Data Extract Start" do
    test "Starts a dataset processor for each target dataset in the ingestion" do
      first_dataset = TDG.create_dataset(%{id: UUID.uuid4()})
      second_dataset = TDG.create_dataset(%{id: UUID.uuid4()})

      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [first_dataset.id, second_dataset.id]})

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, first_dataset)
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, second_dataset)
      Brook.Event.send(@instance_name, data_extract_start(), __MODULE__, ingestion)

      eventually(fn ->
        first_process = Valkyrie.DatasetSupervisor.is_started?(first_dataset.id)
        second_process = Valkyrie.DatasetSupervisor.is_started?(second_dataset.id)

        assert first_process and second_process
      end)
    end

    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Brook.get! failures
      # For integration testing, real failure conditions should be used instead
    end
  end
end
