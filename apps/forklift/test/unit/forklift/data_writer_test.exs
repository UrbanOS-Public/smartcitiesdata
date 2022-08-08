defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :forklift

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:profiling_enabled, generic: false)

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

    stub(MockTable, :write, fn _data, params ->
      schema = params |> Keyword.fetch!(:schema) |> IO.inspect(label: "schema from data_writer")

      schema_with_ingestion_metadata =
        expected_dataset.technical.schema ++
          [
            %{name: "ingestion_id", type: "string"},
            %{name: "ingestion_start", type: "date", format: "{ISO:Extended:Z}"}
          ]

      assert schema == schema_with_ingestion_metadata
      :ok
    end)

    assert :ok ==
             DataWriter.write([fake_data_to_write()], dataset: expected_dataset)
  end

  defp fake_data_to_write() do
    %{_metadata: %{forklift_start_time: DateTime.utc_now()}}
  end
end
