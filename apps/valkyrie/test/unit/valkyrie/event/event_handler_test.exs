defmodule Valkyrie.Event.EventHandlerTest do
  use ExUnit.Case
  import Mox
  use Brook.Event.Handler
  import Checkov

  import SmartCity.Event,
    only: [data_ingest_start: 0, dataset_delete: 0, dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.Event.EventHandler
  alias Valkyrie.DatasetProcessor

  @instance_name Valkyrie.instance_name()

  setup_all do
    set_mox_global()
    verify_on_exit!()
    
    # Set up global mocks for all tests
    stub(ElsaMock, :create_topic, fn _, _ -> :ok end)
    stub(ElsaMock, :delete_topic, fn _, _ -> :ok end)
    stub(ElsaMock, :topic?, fn _, _ -> true end)
    stub(ValkyrierTelemetryEventMock, :add_event_metrics, fn _, _, _ -> :ok end)
    :ok
  end

  setup do
    # Mock setup moved to individual tests
    :ok
  end

  test "Processes ingestions when data:ingest:start event fires" do
    dataset_id = Faker.UUID.v4()
    dataset_id2 = Faker.UUID.v4()
    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset_id, dataset_id2]})
    dataset = TDG.create_dataset(%{id: dataset_id})
    dataset2 = TDG.create_dataset(%{id: dataset_id2})
    # Mock Brook.get! calls as needed

    Brook.Test.with_event(@instance_name, fn ->
      EventHandler.handle_event(Brook.Event.new(type: data_ingest_start(), data: ingestion, author: :author))
    end)

    # TODO: Add proper assertions for DatasetProcessor.start calls
  end

  describe "handle_event/1" do
    setup do
      # Mock TelemetryEvent as needed

      :ok
    end

    test "Should modify viewstate when dataset:update event fires" do
      dataset = TDG.create_dataset(id: "does_not_matter")

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(Brook.Event.new(type: dataset_update(), data: dataset, author: :author))
      end)

      assert Brook.get!(@instance_name, :datasets, dataset.id) == dataset
    end

    test "should delete dataset when dataset:delete event fires" do
      dataset = TDG.create_dataset(id: "does_not_matter", technical: %{sourceType: "ingest"})
      # Mock DatasetProcessor.delete as needed

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: dataset_delete(),
            data: dataset,
            author: :author
          )
        )
      end)

      # TODO: Add proper assertion for DatasetProcessor.delete call
    end
  end
end
