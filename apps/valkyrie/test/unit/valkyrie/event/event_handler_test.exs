defmodule Valkyrie.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  use Brook.Event.Handler
  import Checkov

  import SmartCity.Event,
    only: [data_ingest_start: 0, data_standardization_end: 0, dataset_delete: 0, dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.Event.EventHandler
  alias Valkyrie.DatasetProcessor

  @instance_name Valkyrie.instance_name()

  setup do
    allow(Valkyrie.DatasetProcessor.start(any()), return: :does_not_matter, meck_options: [:passthrough])

    :ok
  end

  test "Processes ingestions when data:ingest:start event fires" do
    ingestion = TDG.create_ingestion(%{targetDataset: "dataset id"})

    Brook.Test.with_event(@instance_name, fn ->
      EventHandler.handle_event(Brook.Event.new(type: data_ingest_start(), data: ingestion, author: :author))
    end)

    assert called?(Valkyrie.DatasetProcessor.start("dataset id"))
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

    test "Deletes dataset from viewstate when data:standarization:end event fires" do
      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: data_standardization_end(),
            data: %{"dataset_id" => "ds1"},
            author: :author
          )
        )
      end)

      assert Brook.get!(@instance_name, :datasets, "ds1") == nil
    end

    test "Calls DatasetProcessor.stop when data:standardization:end event fires" do
      allow(DatasetProcessor.stop("ds1"), return: :does_not_matter)

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: data_standardization_end(),
            data: %{"dataset_id" => "ds1"},
            author: :author
          )
        )
      end)

      assert_called(DatasetProcessor.stop("ds1"))
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
