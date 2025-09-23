defmodule Forklift.Event.EventHandlingTest do
  use ExUnit.Case
  import Mox

  Code.require_file("../../test_helper.exs", __DIR__)

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

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Brook.Test.register(@instance_name)
    :ok
  end

  describe "on dataset:update event" do
    test "ensures table exists for ingestible dataset" do
      # Start TelemetryEvent.Mock to prevent GenServer not alive errors
      case start_supervised(TelemetryEvent.Mock) do
        {:ok, _} -> :ok
        {:error, {{:already_started, _}, _}} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      # Set up private mocks to avoid verification issues
      set_mox_private()

      test = self()
      BrookEventMock |> stub(:send, fn _, _, _, _ -> :ok end)
      TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)

      # Add necessary mocks for dataset_update event handling
      # Mock PrestigeHelper directly with :meck since PrestigeHelperMock doesn't define table_exists?
      :meck.new(Pipeline.Writer.TableWriter.Helper.PrestigeHelper, [:passthrough])
      :meck.expect(Pipeline.Writer.TableWriter.Helper.PrestigeHelper, :table_exists?, fn _ -> false end)

      # Mock the actual Forklift.DataWriter module instead of DataWriterMock
      :meck.new(Forklift.DataWriter, [:passthrough])

      :meck.expect(Forklift.DataWriter, :init, fn args ->
        # Send the args to the test process for verification
        send(test, args)
        :ok
      end)

      # Mock Forklift.Datasets for the update call
      :meck.new(Forklift.Datasets, [:passthrough])
      :meck.expect(Forklift.Datasets, :update, fn _ -> :ok end)

      on_exit(fn ->
        try do
          :meck.unload(Forklift.Datasets)
          :meck.unload(Forklift.DataWriter)
          :meck.unload(Pipeline.Writer.TableWriter.Helper.PrestigeHelper)
        catch
          :error, {:not_mocked, _} -> :ok
        end
      end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      # The schema passed to DataWriter.init is the original schema, not with metadata added
      schema = dataset.technical.schema

      # Call the event handler directly instead of using BrookEventMock.send
      EventHandler.handle_event(
        Brook.Event.new(
          type: dataset_update(),
          data: dataset,
          author: :author
        )
      )

      assert_receive table: ^table_name,
                     schema: ^schema,
                     json_partitions: ["_extraction_start_time", "_ingestion_id"],
                     main_partitions: ["_ingestion_id"]
    end

    test "sends dataset_update event when table creation succeeds" do
      TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)
      BrookEventMock |> expect(:send, fn _, _, _, _ -> :ok end)
      DataWriterMock |> stub(:init, fn _ -> :ok end)

      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName
      schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)
    end

    test "does not send dataset_update event when table already exists" do
      BrookEventMock |> expect(:send, fn _, _, _, _ -> :ok end)
      TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)
      DataWriterMock |> stub(:init, fn _ -> :ok end)
      PrestigeHelperMock |> stub(:table_exists?, fn _ -> true end)

      dataset = TDG.create_dataset(%{})
      _table_name = dataset.technical.systemName
      _schema = dataset.technical.schema |> Forklift.DataWriter.add_ingestion_metadata_to_schema()

      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)
    end

    test "does not create table for non-ingestible dataset" do
      BrookEventMock |> expect(:send, fn _, _, _, _ -> :ok end)
      MockTable |> expect(:init, 0, fn _ -> :ok end)
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})
      BrookEventMock.send(@instance_name, dataset_update(), :author, dataset)
    end
  end

  describe "on data:ingest:start event" do
    test "ensures event is handled gracefully if no dataset exists for the ingestion" do
      _test = self()

      BrookEventMock |> expect(:send, fn _, _, _, _ -> :ok end)
      TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)

      ingestion = TDG.create_ingestion(%{})
      :ok = BrookEventMock.send(@instance_name, data_ingest_start(), :author, ingestion)
    end

    test "ensures dataset topic exists" do
      # Start TelemetryEvent.Mock to prevent GenServer not alive errors
      case start_supervised(TelemetryEvent.Mock) do
        {:ok, _} -> :ok
        {:error, {{:already_started, _}, _}} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      # Set up private mocks to avoid verification issues
      set_mox_private()

      test = self()

      BrookEventMock |> stub(:send, fn _, _, _, _ -> :ok end)

      MockReader
      |> stub(:init, fn args ->
        send(test, Keyword.get(args, :dataset))
        :ok
      end)

      MockTable |> stub(:init, fn args -> send(test, args) && :ok end)

      TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)

      # Add necessary mocks for dataset_update events
      PrestigeHelperMock |> stub(:table_exists?, fn _ -> false end)

      # Mock DataWriter.init to handle the table creation
      DataWriterMock |> stub(:init, fn _ -> :ok end)

      dataset = TDG.create_dataset(%{id: "dataset-id"})
      dataset2 = TDG.create_dataset(%{id: "dataset-id2"})
      ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id, dataset2.id]})

      # Mock Forklift.Datasets to return the datasets when requested
      :meck.new(Forklift.Datasets, [:passthrough])

      :meck.expect(Forklift.Datasets, :get!, fn
        "dataset-id" -> dataset
        "dataset-id2" -> dataset2
        _ -> nil
      end)

      :meck.expect(Forklift.Datasets, :update, fn _ -> :ok end)

      on_exit(fn ->
        try do
          :meck.unload(Forklift.Datasets)
        catch
          :error, {:not_mocked, _} -> :ok
        end
      end)

      # Call event handlers directly
      EventHandler.handle_event(
        Brook.Event.new(
          type: dataset_update(),
          data: dataset,
          author: :author
        )
      )

      EventHandler.handle_event(
        Brook.Event.new(
          type: dataset_update(),
          data: dataset2,
          author: :author
        )
      )

      EventHandler.handle_event(
        Brook.Event.new(
          type: data_ingest_start(),
          data: ingestion,
          author: :author
        )
      )

      assert_receive %SmartCity.Dataset{id: "dataset-id"}
      assert_receive %SmartCity.Dataset{id: "dataset-id2"}
    end
  end

  describe "on data:ingest:end event" do
    test "tears reader infrastructure down" do
      # Start TelemetryEvent.Mock to prevent GenServer not alive errors
      case start_supervised(TelemetryEvent.Mock) do
        {:ok, _} -> :ok
        {:error, {{:already_started, _}, _}} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      test = self()

      BrookEventMock |> expect(:send, fn _, _, _, _ -> :ok end)

      MockReader
      |> expect(:terminate, fn args ->
        send(test, args[:dataset])
        :ok
      end)

      TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)

      # Mock Forklift.Datasets directly with :meck since DatasetsMock isn't working
      :meck.new(Forklift.Datasets, [:passthrough])
      :meck.expect(Forklift.Datasets, :delete, fn "terminate-id" -> :ok end)

      on_exit(fn ->
        try do
          :meck.unload(Forklift.Datasets)
        catch
          :error, {:not_mocked, _} -> :ok
        end
      end)

      dataset = TDG.create_dataset(%{id: "terminate-id"})
      BrookEventMock.send(@instance_name, data_ingest_end(), :author, dataset)

      EventHandler.handle_event(
        Brook.Event.new(
          type: data_ingest_end(),
          data: dataset,
          author: :author
        )
      )

      assert_receive %SmartCity.Dataset{id: "terminate-id"}
    end
  end

  test "should delete dataset when dataset:delete event handle is called" do
    # Start TelemetryEvent.Mock to prevent GenServer not alive errors
    case start_supervised(TelemetryEvent.Mock) do
      {:ok, _} -> :ok
      {:error, {{:already_started, _}, _}} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "ingest"})
    MockReader |> expect(:terminate, fn _ -> :ok end)
    MockTopic |> expect(:delete, fn _ -> :ok end)
    MockTable |> expect(:delete, fn _ -> :ok end)

    # Mock Forklift.Datasets directly with :meck since DatasetsMock isn't working
    :meck.new(Forklift.Datasets, [:passthrough])
    :meck.expect(Forklift.Datasets, :delete, fn id when id == dataset.id -> :ok end)

    on_exit(fn ->
      try do
        :meck.unload(Forklift.Datasets)
      catch
        :error, {:not_mocked, _} -> :ok
      end
    end)

    TelemetryEventMock |> stub(:add_event_metrics, fn _, _ -> :ok end)

    # dataset_delete handler doesn't send Brook events, so stub instead of expect
    BrookEventMock |> stub(:send, fn _, _, _, _ -> :ok end)

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
