defmodule Forklift.Event.EventHandlingTest do
  use ExUnit.Case

  Code.require_file "../../test_helper.exs", __DIR__

  import Forklift.Test.DataWriterBehaviour
  import Forklift.Test.PrestigeHelperBehaviour
  import Forklift.Test.TelemetryEventBehaviour

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      dataset_update: 0,
      data_ingest_end: 0,
      dataset_delete: 0,
      data_extract_end: 0,
      event_log_published: 0
    ]

  alias Forklift.Event.EventHandler
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

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
      expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)
      expect(MockTable, :init, fn args -> send(test, args) end)
      stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)

      assert_receive table: ^table_name,
                     schema: ^schema,
                     json_partitions: ["_extraction_start_time", "_ingestion_id"],
                     main_partitions: ["_ingestion_id"]
    end

    test "sends dataset_update event when table creation succeeds" do
      stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)
      expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)
      stub(DataWriterMock, :init, fn _ -> :ok end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)
    end

    test "does not send dataset_update event when table already exists" do
      import Mox
      expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)
      stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)
      stub(DataWriterMock, :init, fn _ -> :ok end)
      stub(PrestigeHelperMock, :table_exists?, fn _ -> true end)
      
      dataset = TDG.create_dataset(%{})
      _table_name = dataset.technical.systemName
      _schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)

      Mox.refute_called(&BrookEventMock.send/4)
    end

    test "does not create table for non-ingestible dataset" do
      expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)
      expect(MockTable, :init, 0, fn _ -> :ok end)
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})
      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)
    end
  end

  describe "on data:ingest:start event" do
    test "ensures event is handled gracefully if no dataset exists for the ingestion" do
      test = self()

      expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)
      stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)

      ingestion = TDG.create_ingestion(%{})
      :ok = BrookEventMock.send(@instance_name, data_ingest_start(), :author, ingestion)
    end

    test "ensures dataset topic exists" do
      test = self()

      expect(BrookEventMock, :send, 3, fn _, _, _, _ -> :ok end)
      MockReader
      |> expect(:init, fn args ->
        send(test, Keyword.get(args, :dataset))
        :ok
      end)

      MockReader
      |> expect(:init, fn args ->
        send(test, Keyword.get(args, :dataset))
        :ok
      end)

      expect(MockTable, :init, fn args -> send(test, args) end)
      expect(MockTable, :init, fn args -> send(test, args) end)

      stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)

      dataset = TDG.create_dataset(%{id: "dataset-id"})
      dataset2 = TDG.create_dataset(%{id: "dataset-id2"})
      ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id, dataset2.id]})
      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)
      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset2)
      BrookEventMock.send(@instance_name, data_ingest_start(), :author, ingestion)

      assert_receive %SmartCity.Dataset{id: "dataset-id"}
      assert_receive %SmartCity.Dataset{id: "dataset-id2"}
    end
  end

  describe "on data:ingest:end event" do
    test "tears reader infrastructure down" do
      test = self()

      expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)
      expect(MockReader, :terminate, fn args ->
        send(test, args[:dataset])
        :ok
      end)

      stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)

      stub(DatasetsMock, :delete, fn "terminate-id" -> :ok end)

      dataset = TDG.create_dataset(%{id: "terminate-id"})
      BrookEventMock.send(@instance_name, data_ingest_end(), :author, dataset)

      assert_receive %SmartCity.Dataset{id: "terminate-id"}
    end
  end

  test "should delete dataset when dataset:delete event handle is called" do
    dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "ingest"})
    expect(MockReader, :terminate, fn _ -> :ok end)
    expect(MockTopic, :delete, fn _ -> :ok end)
    expect(MockTable, :delete, fn _ -> :ok end)
    stub(DatasetsMock, :delete, fn id when id == dataset.id -> :ok end)
    stub(TelemetryEventMock, :add_event_metrics, fn _, _ -> :ok end)

    expect(BrookEventMock, :send, fn _, _, _, _ -> :ok end)

    EventHandler.handle_event(
      Brook.Event.new(
        type: dataset_delete(),
        data: dataset,
        author: :author
      )
    )
  end

  describe "on data:extract:end event" do
    setup do
      dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream"})
      dataset2 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream"})
      ingestion_id = Faker.UUID.v4()
      extract_start = Timex.now() |> Timex.to_unix()

      fake_extract_end_msg = %{
        "dataset_ids" => [dataset.id, dataset2.id],
        "extract_start_unix" => extract_start,
        "ingestion_id" => ingestion_id
      }

      [
        dataset: dataset,
        dataset2: dataset2,
        ingestion_id: ingestion_id,
        extract_start: extract_start,
        fake_extract_end__msg: fake_extract_end_msg
      ]
    end
  end
end