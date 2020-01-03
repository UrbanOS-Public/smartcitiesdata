defmodule Estuary.Datasets.DatasetSchemaTest do
  # , async: true
  use ExUnit.Case
  use Placebo
  import Mox

  alias Estuary.Datasets.DatasetSchema
  alias SmartCity.TestDataGenerator, as: TDG
  alias Estuary.DataWriterHelper

  setup :set_mox_global
  setup :verify_on_exit!

  @table_name Application.get_env(:estuary, :table_name)

  setup do
    expect(MockReader, :init, fn _ -> :ok end)
    expect(MockTable, :init, fn _ -> :ok end)
  end

  test "should return table and schema" do
    expected_value = [
      table: @table_name,
      schema: [
        %{description: "N/A", name: "author", type: "string"},
        %{description: "N/A", name: "create_ts", type: "long"},
        %{description: "N/A", name: "data", type: "string"},
        %{description: "N/A", name: "type", type: "string"}
      ]
    ]

    actual_value = DatasetSchema.table_schema()
    assert expected_value == actual_value
  end

  test "should return table name" do
    expected_value = @table_name
    actual_value = DatasetSchema.table_name()
    assert expected_value == actual_value
  end

  test "should return schema" do
    expected_value = [
      %{description: "N/A", name: "author", type: "string"},
      %{description: "N/A", name: "create_ts", type: "long"},
      %{description: "N/A", name: "data", type: "string"},
      %{description: "N/A", name: "type", type: "string"}
    ]

    actual_value = DatasetSchema.schema()
    assert expected_value == actual_value
  end

  test "should return payload when given ingest SmartCity Dataset struct" do
    author = DataWriterHelper.make_author()
    time_stamp = DataWriterHelper.make_time_stamp()
    dataset = TDG.create_dataset(%{})

    expected_value = [
      %{
        payload: %{
          "author" => author,
          "create_ts" => time_stamp,
          "data" => Jason.encode!(dataset),
          "type" => "data:ingest:start"
        }
      }
    ]

    actual_value =
      %{
        author: author,
        create_ts: time_stamp,
        data: dataset,
        forwarded: false,
        type: "data:ingest:start"
      }
      |> DatasetSchema.make_datawriter_payload()

    assert expected_value == actual_value
  end
end
