defmodule Estuary.Datasets.DatasetSchemaTest do
  use ExUnit.Case

  alias Estuary.Datasets.DatasetSchema
  alias SmartCity.TestDataGenerator, as: TDG

  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  test "should return table and schema" do
    expected_value = [
      table: @event_stream_table_name,
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
    expected_value = @event_stream_table_name
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
    dataset = TDG.create_dataset(%{})

    event = %{
      author: "some_author",
      create_ts: 1_575_308_549_008,
      data: dataset,
      forwarded: false,
      type: "data:ingest:start"
    }

    expected_value = [
      %{
        payload: %{
          "author" => "some_author",
          "create_ts" => 1_575_308_549_008,
          "data" => dataset,
          "type" => "data:ingest:start"
        }
      }
    ]

    actual_value = DatasetSchema.parse_event_args(event)
    assert expected_value == actual_value
  end
end
