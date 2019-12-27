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

  test "should insert event to history table" do
    author = DataWriterHelper.make_author()
    time_stamp = DataWriterHelper.make_time_stamp()
    dataset = TDG.create_dataset(%{})

    expected_value = [
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

    actual_value =
      "'#{author}'"
      |> DataWriterHelper.get_events_by_author()

    assert expected_value == actual_value
  end
end
