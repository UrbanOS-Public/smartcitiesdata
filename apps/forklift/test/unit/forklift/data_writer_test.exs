defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :forklift

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:table_writer, generic: true)

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    allow(Forklift.IngestionProgress.new_messages(any(), any(), any(), any()), return: :in_progress)
    :ok
  end

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

  test "should raise exception when writer fails" do
    ingestion_status = :in_progress

    ingestion_id = "1234-abcd"
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = [TDG.create_data(%{}), TDG.create_data(%{})]

    allow(Forklift.IngestionProgress.new_messages(Enum.count(fake_data), ingestion_id, dataset.id, extract_start),
      return: ingestion_status
    )

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

  test "compaction *is not* kicked off if ingestion_progress reports \"in progress\"" do
    ingestion_status = :in_progress

    ingestion_id = "1234-abcd"
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = [TDG.create_data(%{}), TDG.create_data(%{})]

    allow(Forklift.IngestionProgress.new_messages(Enum.count(fake_data), ingestion_id, dataset.id, extract_start),
      return: ingestion_status
    )

    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    assert_called Forklift.IngestionProgress.new_messages(Enum.count(fake_data), ingestion_id, dataset.id, extract_start), once()
    refute_called Forklift.Jobs.DataMigration.compact(any(), any(), any())
  end

  test "compaction *is* kicked off if ingestion_progress reports \"ingestion_complete\"" do
    ingestion_status = :ingestion_complete

    ingestion_id = "1234-abcd"
    extract_start = 1_662_175_490

    dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    fake_data = [TDG.create_data(%{})]

    allow(Forklift.IngestionProgress.new_messages(Enum.count(fake_data), ingestion_id, dataset.id, extract_start),
      return: ingestion_status
    )

    allow(Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), return: {:ok, dataset.id})

    stub(MockTable, :write, fn _data, _params ->
      :ok
    end)

    DataWriter.write(fake_data,
      dataset: dataset,
      ingestion_id: ingestion_id,
      extraction_start_time: extract_start
    )

    assert_called Forklift.IngestionProgress.new_messages(Enum.count(fake_data), ingestion_id, dataset.id, extract_start), once()
    assert_called Forklift.Jobs.DataMigration.compact(dataset, ingestion_id, extract_start), once()
  end
end
