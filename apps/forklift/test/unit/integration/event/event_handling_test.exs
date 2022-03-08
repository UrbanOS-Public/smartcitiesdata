defmodule Forklift.Event.EventHandlingTest do
  use ExUnit.Case
  use Placebo

  import Mox

  import SmartCity.Event,
    only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0, dataset_delete: 0]

  alias Forklift.Event.EventHandler
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Forklift.instance_name()

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    Brook.Test.register(@instance_name)
    :ok
  end

  describe "on dataset:update event" do
    test "ensures table exists for ingestible dataset" do
      test = self()
      expect(MockTable, :init, fn args -> send(test, args) end)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      schema = dataset.technical.schema

      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)
      assert_receive table: ^table_name, schema: ^schema
    end

    test "does not create table for non-ingestible dataset" do
      expect(MockTable, :init, 0, fn _ -> :ok end)
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})
      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)
    end

    test "sends error event for raised errors while performing dataset update" do
      stub(MockTable, :init, fn _ -> raise "bad stuff" end)
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{})

      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)

      assert_receive {:brook_event,
                      %Brook.Event{
                        type: "error:dataset:update",
                        data: %{"reason" => %RuntimeError{message: "bad stuff"}, "dataset" => _}
                      }},
                     10_000
    end
  end

  describe "on data:ingest:start event" do
    test "ensures event is handled gracefully if no dataset exists for the ingestion" do
      test = self()

      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      ingestion = TDG.create_ingestion(%{})
      :ok = Brook.Test.send(@instance_name, data_ingest_start(), :author, ingestion)

    end

    test "ensures dataset topic exists" do
      test = self()

      MockReader
      |> expect(:init, fn args ->
        send(test, Keyword.get(args, :dataset))
        :ok
      end)

      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{id: "dataset-id"})
      ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})
      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)
      Brook.Test.send(@instance_name, data_ingest_start(), :author, ingestion)

      assert_receive %SmartCity.Dataset{id: "dataset-id"}
    end
  end

  describe "on data:ingest:end event" do
    test "tears reader infrastructure down" do
      test = self()

      expect(MockReader, :terminate, fn args ->
        send(test, args[:dataset])
        :ok
      end)

      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      expect Forklift.Datasets.delete("terminate-id"), return: :ok

      dataset = TDG.create_dataset(%{id: "terminate-id"})
      Brook.Test.send(@instance_name, data_ingest_end(), :author, dataset)

      assert_receive %SmartCity.Dataset{id: "terminate-id"}
    end
  end

  test "should delete dataset when dataset:delete event handle is called" do
    dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "ingest"})
    expect(MockReader, :terminate, fn _ -> :ok end)
    expect(MockTopic, :delete, fn _ -> :ok end)
    expect(MockTable, :delete, fn _ -> :ok end)
    expect(Forklift.Datasets.delete(dataset.id), return: :ok)
    expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

    Brook.Test.with_event(@instance_name, fn ->
      EventHandler.handle_event(
        Brook.Event.new(
          type: dataset_delete(),
          data: dataset,
          author: :author
        )
      )
    end)
  end
end
