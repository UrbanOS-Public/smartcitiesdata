defmodule Alchemist.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  use Brook.Event.Handler
  import Checkov
  import SmartCity.Event, only: [data_ingest_start: 0, data_standardization_end: 0, dataset_delete: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Alchemist.Event.EventHandler
  alias Alchemist.DatasetProcessor

  @instance_name Alchemist.instance_name()

  setup do
    allow(Alchemist.DatasetProcessor.start(any()), return: :does_not_matter, meck_options: [:passthrough])

    :ok
  end

  data_test "Processes datasets with #{source_type} " do
    dataset = TDG.create_dataset(id: "does_not_matter", technical: %{sourceType: source_type})

    Brook.Test.with_event(@instance_name, fn ->
      EventHandler.handle_event(Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author))
    end)

    assert called == called?(Alchemist.DatasetProcessor.start(dataset))

    where([
      [:source_type, :called],
      ["ingest", true],
      ["stream", true],
      ["host", false],
      ["remote", false],
      ["invalid", false]
    ])
  end

  describe "handle_event/1" do
    setup do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      :ok
    end

    test "Should modify viewstate when handled" do
      dataset = TDG.create_dataset(id: "does_not_matter", technical: %{sourceType: "ingest"})

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author))
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
