defmodule Forklift.Event.EventHandlingTest do
  use ExUnit.Case
  use Placebo

  import Mox

  import SmartCity.Event,
    only: [data_ingest_start: 0, dataset_update: 0, data_ingest_end: 0, dataset_delete: 0, data_extract_end: 0]

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
      schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)

      assert_receive table: ^table_name,
                     schema: ^schema,
                     json_partitions: ["_extraction_start_time", "_ingestion_id"],
                     main_partitions: ["_ingestion_id"]
    end

    test "sends dataset_update event when table creation succeeds" do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
      expect(Brook.Event.send(@instance_name, "table:created", :forklift, any()), return: :ok)
      allow(Forklift.DataWriter.init(any()), return: :ok)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)
    end

    test "does not create table for non-ingestible dataset" do
      expect(MockTable, :init, 0, fn _ -> :ok end)
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})
      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)
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

      MockReader
      |> expect(:init, fn args ->
        send(test, Keyword.get(args, :dataset))
        :ok
      end)

      expect(MockTable, :init, fn args -> send(test, args) end)
      expect(MockTable, :init, fn args -> send(test, args) end)

      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset = TDG.create_dataset(%{id: "dataset-id"})
      dataset2 = TDG.create_dataset(%{id: "dataset-id2"})
      ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id, dataset2.id]})
      Brook.Test.send(@instance_name, dataset_update(), :author, dataset)
      Brook.Test.send(@instance_name, dataset_update(), :author, dataset2)
      Brook.Test.send(@instance_name, data_ingest_start(), :author, ingestion)

      assert_receive %SmartCity.Dataset{id: "dataset-id"}
      assert_receive %SmartCity.Dataset{id: "dataset-id2"}
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

  describe "on data:extract:end event" do
    setup do
      dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream"})
      dataset2 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream"})
      ingestion_id = Faker.UUID.v4()
      msg_target = 5
      extract_start = Timex.now() |> Timex.to_unix()

      fake_extract_end_msg = %{
        "dataset_ids" => [dataset.id, dataset2.id],
        "extract_start_unix" => extract_start,
        "ingestion_id" => ingestion_id,
        "msgs_extracted" => msg_target
      }

      [
        dataset: dataset,
        dataset2: dataset2,
        ingestion_id: ingestion_id,
        extract_start: extract_start,
        msg_target: msg_target,
        fake_extract_end_msg: fake_extract_end_msg
      ]
    end

    test "stores ingestion_progress target message count", %{
      dataset: dataset,
      dataset2: dataset2,
      ingestion_id: ingestion_id,
      extract_start: extract_start,
      msg_target: msg_target,
      fake_extract_end_msg: fake_extract_end_msg
    } do
      expect(Forklift.IngestionProgress.store_target(dataset, msg_target, ingestion_id, extract_start),
        return: :in_progress
      )

      expect(Forklift.IngestionProgress.store_target(dataset2, msg_target, ingestion_id, extract_start),
        return: :in_progress
      )

      expect(Forklift.Datasets.get!(dataset.id), return: dataset)
      expect(Forklift.Datasets.get!(dataset2.id), return: dataset2)

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: data_extract_end(),
            data: fake_extract_end_msg,
            author: :author
          )
        )
      end)
    end

    test "kicks off compaction if ingestion_progress is complete", %{
      dataset: dataset,
      dataset2: dataset2,
      ingestion_id: ingestion_id,
      extract_start: extract_start,
      msg_target: msg_target,
      fake_extract_end_msg: fake_extract_end_msg
    } do
      expect(Forklift.IngestionProgress.store_target(dataset, msg_target, ingestion_id, extract_start),
        return: :ingestion_complete
      )

      expect(Forklift.IngestionProgress.store_target(dataset2, msg_target, ingestion_id, extract_start),
        return: :ingestion_complete
      )

      expect(Forklift.Datasets.get!(dataset.id), return: dataset)
      expect(Forklift.Datasets.get!(dataset2.id), return: dataset2)
      expect(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})
      expect(Forklift.Jobs.DataMigration.compact(dataset2, ingestion_id, extract_start), return: {:ok, dataset2.id})

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: data_extract_end(),
            data: fake_extract_end_msg,
            author: :author
          )
        )
      end)
    end

    test "*does not* kick off compaction if ingestion_progress is not complete", %{
      dataset: dataset,
      dataset2: dataset2,
      ingestion_id: ingestion_id,
      extract_start: extract_start,
      msg_target: msg_target,
      fake_extract_end_msg: fake_extract_end_msg
    } do
      expect(Forklift.IngestionProgress.store_target(dataset, msg_target, ingestion_id, extract_start),
        return: :in_progress
      )

      expect(Forklift.IngestionProgress.store_target(dataset2, msg_target, ingestion_id, extract_start),
        return: :in_progress
      )

      allow(Forklift.Datasets.get!(dataset.id), return: dataset)
      allow(Forklift.Datasets.get!(dataset2.id), return: dataset2)
      allow(Forklift.Jobs.DataMigration.compact(dataset, any(), any()), return: {:ok, dataset.id})
      allow(Forklift.Jobs.DataMigration.compact(dataset2, any(), any()), return: {:ok, dataset2.id})

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: data_extract_end(),
            data: fake_extract_end_msg,
            author: :author
          )
        )
      end)

      refute_called Forklift.Jobs.DataMigration.compact(any(), any(), any())
    end
  end
end
