defmodule Estuary.EventTableTest do
  use ExUnit.Case
  use Divo

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias Estuary.EventTableHelper
  alias SmartCity.TestDataGenerator, as: TDG

  @event_stream_schema_name Application.get_env(:estuary, :event_stream_schema_name)
  @table_name Application.get_env(:estuary, :table_name)

  # test "create_schema is idempotent" do
  #   expected_value = :ok
  #   expected_schema_value = [[@event_stream_schema_name]]
  #   DatasetSchema.table_schema()
  #   |> DataWriter.init()
  #   EventTable.create_schema()
  #   actual_value = EventTable.create_schema()

  #   actual_schema_value =
  #     "SHOW SCHEMAS in hive LIKE '#{@event_stream_schema_name}'"
  #     |> Prestige.execute()
  #     |> Prestige.prefetch()

  #   assert expected_value == actual_value
  #   assert expected_schema_value == actual_schema_value
  # end

  test "create_table is idempotent" do
    expected_value = :ok
    expected_table_value = [[@table_name]]
    DatasetSchema.table_schema()
    |> DataWriter.init()
    actual_value = 
    DatasetSchema.table_schema()
    |> DataWriter.init()

    actual_table_value =
      "SHOW TABLES LIKE '#{@table_name}'"
      |> Prestige.execute()
      |> Prestige.prefetch()

    assert expected_value == actual_value
    assert expected_table_value == actual_table_value
  end

  test "should insert event to event_stream table" do
    dataset = TDG.create_dataset(%{})
    expected_value_after_insert = [["Steve", 1_575_308_549_008, Jason.encode!(dataset), "data:ingest:start"]]

    %{
      author: "Steve",
      create_ts: 1_575_308_549_008,
      data: dataset,
      forwarded: false,
      type: "data:ingest:start"
    }
    |> DatasetSchema.make_datawriter_payload()
    |> DataWriter.write()

    actual_value_after_insert =
      "'Steve'"
      |> EventTableHelper.get_events_by_author()

    assert expected_value_after_insert == actual_value_after_insert
    EventTableHelper.delete_all_events_in_table()
  end

  # test "should fail when improper value of timestamp is passed" do
  #   dataset = TDG.create_dataset(%{})
  #   expected_value = "SYNTAX_ERROR"
  #   actual_value = %{
  #     author: "Steve",
  #     create_ts: "'1_575_308_549_008'",
  #     data: dataset,
  #     forwarded: false,
  #     type: "data:ingest:start"
  #   }
  #   |> DatasetSchema.make_datawriter_payload()
  #   |> DataWriter.write()
  #   |> IO.inspect(label: "Errorrrrr")

  #   {:error, %Prestige.Error{name: error}} = actual_value

  #   assert expected_value == error
  # end
end
