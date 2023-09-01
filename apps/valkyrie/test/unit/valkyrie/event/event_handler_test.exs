defmodule Valkyrie.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  use Brook.Event.Handler
  import Checkov

  import SmartCity.Event,
    only: [data_ingest_start: 0, dataset_delete: 0, dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.Event.EventHandler
  alias Valkyrie.DatasetProcessor

  @instance_name Valkyrie.instance_name()

  setup do
    allow(Valkyrie.DatasetProcessor.start(any()), return: :does_not_matter, meck_options: [:passthrough])

    :ok
  end

  test "Processes ingestions when data:ingest:start event fires" do
    dataset_id = Faker.UUID.v4()
    dataset_id2 = Faker.UUID.v4()
    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset_id, dataset_id2]})
    dataset = TDG.create_dataset(%{id: dataset_id})
    dataset2 = TDG.create_dataset(%{id: dataset_id2})
    allow(Brook.get!(any(), any(), dataset_id), return: dataset)
    allow(Brook.get!(any(), any(), dataset_id2), return: dataset2)

    Brook.Test.with_event(@instance_name, fn ->
      EventHandler.handle_event(Brook.Event.new(type: data_ingest_start(), data: ingestion, author: :author))
    end)

    assert called?(Valkyrie.DatasetProcessor.start(dataset))
    assert called?(Valkyrie.DatasetProcessor.start(dataset2))
  end

  describe "handle_event/1" do
    setup do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

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
      allow(DatasetProcessor.delete(any()), return: :ok)

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: dataset_delete(),
            data: dataset,
            author: :author
          )
        )
      end)

      assert_called(DatasetProcessor.delete(dataset.id))
    end
  end
end
