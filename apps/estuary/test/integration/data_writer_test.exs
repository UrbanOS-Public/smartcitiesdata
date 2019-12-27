defmodule Estuary.DataWriterTest do
  use ExUnit.Case
  use Divo

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias Estuary.DataWriterHelper
  alias SmartCity.TestDataGenerator, as: TDG

  @table_name Application.get_env(:estuary, :table_name)

  setup do
    on_exit(fn ->
      DataWriterHelper.delete_all_events_in_table()
    end)
  end

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
    author = DataWriterHelper.make_author()
    time_stamp = DataWriterHelper.make_time_stamp()
    dataset = TDG.create_dataset(%{})

    expected_value_after_insert = [
      [author, time_stamp, Jason.encode!(dataset), "data:ingest:start"]
    ]

    %{
      author: author,
      create_ts: time_stamp,
      data: dataset,
      forwarded: false,
      type: "data:ingest:start"
    }
    |> DatasetSchema.make_datawriter_payload()
    |> DataWriter.write()

    actual_value_after_insert =
      "'#{author}'"
      |> EventTableHelper.get_events_by_author()

    assert expected_value_after_insert == actual_value_after_insert
    EventTableHelper.delete_all_events_in_table()
  end

  test "should fail when improper value of timestamp is passed" do
    dataset = TDG.create_dataset(%{})
    expected_value = "SYNTAX_ERROR"

    actual_value =
      %{
        author: DataWriterHelper.make_author(),
        create_ts: "'#{DataWriterHelper.make_time_stamp()}'",
        data: dataset,
        forwarded: false,
        type: "data:ingest:start"
      }
      |> DatasetSchema.make_datawriter_payload()
      |> DataWriter.write()

    {:error, %Prestige.Error{name: error}} = actual_value

    assert expected_value == error
  end
end
