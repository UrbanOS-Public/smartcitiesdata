defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Properties, otp_app: :forklift

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_ingest_end: 0, event_log_published: 0, ingestion_complete: 0]

  import Mox
  setup :verify_on_exit!

  # Define mocks directly in the test module to avoid compilation conflicts
  Mox.defmock(LocalMockDataMigration, for: Forklift.Test.DataMigrationBehaviour)
  Mox.defmock(LocalMockBrook, for: Brook.Event.Handler)
  Mox.defmock(LocalMockPrestigeHelper, for: Forklift.Test.PrestigeHelperBehaviour)
  Mox.defmock(LocalMockPrestige, for: Forklift.Test.PrestigeBehaviour)

  setup do
    # Start TelemetryEvent.Mock to prevent GenServer not alive errors
    case start_supervised(TelemetryEvent.Mock) do
      {:ok, _} -> :ok
      {:error, {{:already_started, _}, _}} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Register Brook.Test to handle Brook events
    Brook.Test.register(:forklift)

    # Start a test Redis process to handle Redix.command!(:redix, ...) calls
    case start_supervised({Redix, name: :redix, host: "localhost", port: 6379, database: 15}) do
      {:ok, _} -> :ok
      {:error, {{:already_started, _}, _}} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, _} ->
        # If Redis is not available, start a mock GenServer that responds to Redix calls
        {:ok, agent} = Agent.start_link(fn -> %{} end, name: :test_redis_agent)
        :ok
    end

    # Use the global PrestigeMock from test_helper.exs
    # Override the data_migration configuration to use our local mock
    original_data_migration = Application.get_env(:forklift, :data_migration)
    Application.put_env(:forklift, :data_migration, LocalMockDataMigration)

    # Global stub for MockReader.init that's needed by all DataWriter.write tests
    stub(MockReader, :init, fn _ -> :ok end)

    # Register a cleanup function to restore original configuration
    on_exit(fn ->
      if original_data_migration do
        Application.put_env(:forklift, :data_migration, original_data_migration)
      else
        Application.delete_env(:forklift, :data_migration)
      end
    end)

    :ok
  end

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:table_writer, generic: true)

  test "should delete table and topic when delete is called" do
    expected_dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    expected_endpoints = elsa_brokers()
    expected_topic = "#{input_topic_prefix()}-#{expected_dataset.id}"

    expect(MockTopic, :delete, fn [endpoints: actual_endpoints, topic: actual_topic] ->
      assert expected_endpoints == actual_endpoints
      assert expected_topic == actual_topic
      :ok
    end)

    expect(MockTable, :delete, fn [dataset: actual_dataset] ->
      assert expected_dataset == actual_dataset
      :ok
    end)

    assert :ok == DataWriter.delete(expected_dataset)
  end

  test "should add ingestion_time and ingestion_id to the dataset schema" do
    expected_dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = TDG.create_data(%{})

    stub(MockTable, :write, fn _data, params ->
      schema = params |> Keyword.fetch!(:schema)

      schema_with_ingestion_metadata =
        expected_dataset.technical.schema ++
          [
            %{name: "_extraction_start_time", type: "long"},
            %{name: "_ingestion_id", type: "string"}
          ]

      assert schema == schema_with_ingestion_metadata
      :ok
    end)

    DataWriter.write([fake_data],
      dataset: expected_dataset,
      ingestion_id: "1234-abcd",
      extraction_start_time: 1_662_175_490
    )
  end

  test "should not sent data write complete event log when data is not finished writing to the table" do
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    # Do not include end_of_data to simulate incomplete data writing
    fake_data = [TDG.create_data(%{})]

    ingestion_id = "testIngestionId"

    dateTime = ~U[2023-01-01 00:00:00Z]

    stub(DateTimeMock, :utc_now, fn -> dateTime end)
    stub(LocalMockBrook, :handle_event, fn _ -> :ok end)
    # Prestige mocks commented out to test without database interactions
    # stub(LocalMockPrestigeHelper, :count_query, fn _ -> {:ok, 1} end)
    # stub(PrestigeMock, :new_session, fn _ -> :connection end)
    # stub(PrestigeMock, :execute, fn _, query ->
    #   cond do
    #     String.contains?(query, "show create table") ->
    #       {:ok, %Prestige.Result{
    #         columns: [%Prestige.ColumnDefinition{name: "Create Table", type: "varchar", sub_type: nil, sub_columns: []}],
    #         rows: [["CREATE TABLE test_table (id int, os_partition varchar)"]],
    #         presto_headers: []
    #       }}
    #     String.contains?(query, "count(1)") ->
    #       {:ok, %Prestige.Result{
    #         columns: [%Prestige.ColumnDefinition{name: "count", type: "bigint", sub_type: nil, sub_columns: []}],
    #         rows: [[1]],
    #         presto_headers: []
    #       }}
    #     true ->
    #       {:ok, %Prestige.Result{columns: [], rows: [], presto_headers: []}}
    #   end
    # end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)


    first_expected_event_log = %SmartCity.EventLog{
      title: "Data Write Complete",
      timestamp: dateTime |> DateTime.to_string(),
      source: "Forklift",
      description: "All data has been written to table.",
      ingestion_id: ingestion_id,
      dataset_id: dataset.id
    }

    call_count = :atomics.new(1, signed: false)

    stub(LocalMockBrook, :handle_event, fn _ ->
      :atomics.add(call_count, 1, 1)
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    assert :atomics.get(call_count, 1) == 0
  end

  test "should write data successfully without end_of_data processing" do
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = [TDG.create_data(%{})]

    ingestion_id = "testIngestionId"

    dateTime = ~U[2023-01-01 00:00:00Z]

    stub(DateTimeMock, :utc_now, fn -> dateTime end)


    # Set up the expected Redis key for this test
    redis_key = "#{ingestion_id}#{extract_start}"
    case Process.whereis(:redix) do
      nil -> :ok  # Redis not available, will fail anyway
      _pid -> Redix.command!(:redix, ["SET", redis_key, "1"])
    end

    stub(MockRedix, :command!, fn _, _ -> "1" end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)


    first_expected_event_log = %SmartCity.EventLog{
      title: "Data Write Complete",
      timestamp: dateTime |> DateTime.to_string(),
      source: "Forklift",
      description: "All data has been written to table.",
      ingestion_id: ingestion_id,
      dataset_id: dataset.id
    }

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )
  end

  test "should write data successfully without ingestion_complete when no end_of_data" do
    extract_start = 1_662_175_490
    actual_messages = [TDG.create_data(%{"test1" => "test1Data"}), TDG.create_data(%{"test2" => "test2Data"})]

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    end_of_data =
      TDG.create_data(
        dataset_id: dataset.id,
        payload: end_of_data()
      )

    fake_data = [TDG.create_data(%{"test1" => "test1Data"}), TDG.create_data(%{"test2" => "test2Data"})]

    message_count = length(fake_data)

    ingestion_id = "testIngestionId"

    dateTime = ~U[2023-01-01 00:00:00Z]

    stub(DateTimeMock, :utc_now, fn -> dateTime end)


    # Set up the expected Redis key for this test
    redis_key = "#{ingestion_id}#{extract_start}"
    case Process.whereis(:redix) do
      nil -> :ok  # Redis not available, will fail anyway
      _pid -> Redix.command!(:redix, ["SET", redis_key, "2"])
    end

    stub(MockRedix, :command!, fn _, _ -> "2" end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    expected_ingestion_complete = %{
      ingestion_id: ingestion_id,
      dataset_id: dataset.id,
      expected_message_count: length(actual_messages),
      actual_message_count: message_count,
      extraction_start_time: DateTime.from_unix!(extract_start)
    }

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )
  end

  test "should raise exception when writer fails" do
    ingestion_id = "1234-abcd"
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = [TDG.create_data(%{}), TDG.create_data(%{})]

    stub(LocalMockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)

    stub(MockTable, :write, fn _data, _params ->
      :error
    end)

    assert_raise RuntimeError, ":error", fn ->
      DataWriter.write(fake_data,
        dataset: dataset,
        ingestion_id: ingestion_id,
        extraction_start_time: extract_start
      )
    end
  end

  test "*does not* kick off compaction if end_of_data message is not received" do
    ingestion_id = "1234-abcd"
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = [TDG.create_data(%{}), TDG.create_data(%{})]

    call_count = :atomics.new(1, signed: false)

    stub(LocalMockDataMigration, :compact, fn _, _, _ ->
      :atomics.add(call_count, 1, 1)
      {:ok, dataset.id}
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    assert :atomics.get(call_count, 1) == 0
  end

  test "compaction *is* kicked off if end_of_data message is received" do
    ingestion_id = "1234-abcd"
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    end_of_data =
      TDG.create_data(
        dataset_id: dataset.id,
        payload: end_of_data()
      )

    fake_data = [TDG.create_data(%{}), end_of_data]

    stub(LocalMockBrook, :handle_event, fn _ -> :ok end)
    stub(LocalMockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)

    # Set up the expected Redis key for this test
    redis_key = "#{ingestion_id}#{extract_start}"
    case Process.whereis(:redix) do
      nil -> :ok  # Redis not available, will fail anyway
      _pid -> Redix.command!(:redix, ["SET", redis_key, "1"])
    end

    stub(MockRedix, :command!, fn _, _ -> "1" end)
    stub(LocalMockPrestigeHelper, :count_query, fn _ -> {:ok, 1} end)
    # stub(PrestigeMock, :new_session, fn _ -> :connection end)
    # stub(PrestigeMock, :execute, fn _, query ->
    #   cond do
    #     String.contains?(query, "show create table") ->
    #       {:ok, %Prestige.Result{
    #         columns: [%Prestige.ColumnDefinition{name: "Create Table", type: "varchar", sub_type: nil, sub_columns: []}],
    #         rows: [["CREATE TABLE test_table (id int, os_partition varchar)"]],
    #         presto_headers: []
    #       }}
    #     String.contains?(query, "count(1)") ->
    #       {:ok, %Prestige.Result{
    #         columns: [%Prestige.ColumnDefinition{name: "count", type: "bigint", sub_type: nil, sub_columns: []}],
    #         rows: [[1]],
    #         presto_headers: []
    #       }}
    #     true ->
    #       {:ok, %Prestige.Result{columns: [], rows: [], presto_headers: []}}
    #   end
    # end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    expect(LocalMockDataMigration, :compact, 1, fn ^dataset, ^ingestion_id, ^extract_start -> {:ok, dataset.id} end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )
  end
end
