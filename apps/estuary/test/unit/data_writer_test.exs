defmodule Estuary.DataWriterTest do
  use ExUnit.Case

  import Mox

  alias Estuary.Datasets.DatasetSchema
  alias Estuary.DataWriter
  alias Estuary.DataWriterHelper
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  test "create_table is idempotent" do
    expect(MockTable, :init, 2, fn _ -> :ok end)

    DatasetSchema.table_schema()
    |> DataWriter.init()

    actual_value =
      DatasetSchema.table_schema()
      |> DataWriter.init()

    assert :ok == actual_value
  end

  test "should insert event to history table" do
    expect(MockTable, :write, fn _, _ -> :ok end)
    author = DataWriterHelper.make_author()
    time_stamp = DataWriterHelper.make_time_stamp()
    dataset = TDG.create_dataset(%{})

    actual_value =
      %{
        "author" => author,
        "create_ts" => time_stamp,
        "data" => dataset,
        "forwarded" => false,
        "type" => "data:ingest:start"
      }
      |> DataWriter.write()

    assert :ok == actual_value
  end
end
