defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :forklift

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox
  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_ingest_end: 0, event_log_published: 0]

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:table_writer, generic: true)

  setup :set_mox_global
  setup :verify_on_exit!

  test "should delete table and topic when delete is called" do
    expected_dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    expected_endpoints = elsa_brokers()
    expected_topic = "#{input_topic_prefix()}-#{expected_dataset.id}"

    stub(MockTopic, :delete, fn [endpoints: actual_endpoints, topic: actual_topic] ->
      assert expected_endpoints == actual_endpoints
      assert expected_topic == actual_topic
      :ok
    end)

    stub(MockTable, :delete, fn [dataset: actual_dataset] ->
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

    allow(DateTime.utc_now(), return: dateTime)

    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})
    allow(Brook.Event.send(any(), event_log_published(), :forklift, any()), return: :ok)
    allow(Brook.Event.send(any(), data_ingest_end(), :forklift, any()), return: :ok)

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

    assert_called(Brook.Event.send(any(), event_log_published(), :forklift, any()), times(0))

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )
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

    allow(DateTime.utc_now(), return: dateTime)

    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})
    allow(Brook.Event.send(any(), data_ingest_end(), :forklift, dataset), return: :ok)

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

    expect(Brook.Event.send(any(), event_log_published(), :forklift, first_expected_event_log), return: :ok)

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

    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})

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

    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    refute_called Forklift.Jobs.DataMigration.compact(any(), any(), any())
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

    allow(Brook.Event.send(any(), event_log_published(), :forklift, any()), return: :ok)
    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    assert_called Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), once()
  end
end
