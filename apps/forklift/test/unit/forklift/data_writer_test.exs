defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Properties, otp_app: :forklift

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  Mox.defmock(MockTopic, for: Pipeline.Writer)
  Mox.defmock(MockTable, for: Pipeline.Writer)
  Mox.defmock(MockBrook, for: Brook.Event.Handler)
  Mox.defmock(MockDateTime, for: Forklift.Test.DateTimeBehaviour)
  Mox.defmock(MockDataMigration, for: Forklift.Test.DataMigrationBehaviour)
  Mox.defmock(MockRedix, for: Forklift.Test.RedixBehaviour)
  Mox.defmock(MockPrestigeHelper, for: Forklift.Test.PrestigeHelperBehaviour)
  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_ingest_end: 0, event_log_published: 0, ingestion_complete: 0]

  import Mox
  setup :verify_on_exit!
 
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

    end_of_data =
      TDG.create_data(
        dataset_id: dataset.id,
        payload: end_of_data()
      )

    fake_data = [TDG.create_data(%{}), end_of_data]

    ingestion_id = "testIngestionId"

    dateTime = ~U[2023-01-01 00:00:00Z]

    stub(MockDateTime, :utc_now, fn -> dateTime end)

    stub(MockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)
    stub(MockBrook, :handle_event, fn _ -> :ok end)
    stub(MockRedix, :command!, fn _, _ -> "1" end)
    stub(MockPrestigeHelper, :count_query, fn _ -> {:ok, 1} end)

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

    call_count = :atomics.new(1, [signed: false])

    stub(MockBrook, :handle_event, fn _ ->
      :atomics.add(call_count, 1, 1)
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    assert :atomics.get(call_count, 1) == 1
  end

  test "should sent data write complete event log when data is finished writing to the table" do
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

    ingestion_id = "testIngestionId"

    dateTime = ~U[2023-01-01 00:00:00Z]

    stub(MockDateTime, :utc_now, fn -> dateTime end)

    stub(MockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)
    stub(MockBrook, :handle_event, fn _ -> :ok end)
    stub(MockRedix, :command!, fn _, _ -> "1" end)
    stub(MockPrestigeHelper, :count_query, fn _ -> {:ok, 1} end)

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

    expect(MockBrook, :handle_event, fn event ->
      assert event.data == first_expected_event_log
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )
  end

  test "should sent ingestion_complete event when data is finished writing to the table" do
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

    fake_data = [TDG.create_data(%{"test1" => "test1Data"}), TDG.create_data(%{"test2" => "test2Data"}), end_of_data]

    message_count = length(fake_data) - 1

    ingestion_id = "testIngestionId"

    dateTime = ~U[2023-01-01 00:00:00Z]

    stub(MockDateTime, :utc_now, fn -> dateTime end)

    stub(MockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)
    stub(MockBrook, :handle_event, fn _ -> :ok end)
    stub(MockRedix, :command!, fn _, _ -> "2" end)
    stub(MockPrestigeHelper, :count_query, fn _ -> {:ok, length(actual_messages)} end)

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

    expect(MockBrook, :handle_event, fn event ->
      assert event.data == expected_ingestion_complete
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

    stub(MockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)

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

    call_count = :atomics.new(1, [signed: false])

    stub(MockDataMigration, :compact, fn _, _, _ ->
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

    assert :atomics.get(call_count, 1) == 1
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

    stub(MockBrook, :handle_event, fn _ -> :ok end)
    stub(MockDataMigration, :compact, fn _, _, _ -> {:ok, dataset.id} end)
    stub(MockRedix, :command!, fn _, _ -> "1" end)
    stub(MockPrestigeHelper, :count_query, fn _ -> {:ok, 1} end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    expect(MockDataMigration, :compact, 1, fn ^dataset, ^ingestion_id, ^extract_start -> {:ok, dataset.id} end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )
  end
end
