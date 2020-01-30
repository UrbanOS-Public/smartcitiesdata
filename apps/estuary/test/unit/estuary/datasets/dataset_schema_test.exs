defmodule Estuary.Datasets.DatasetSchemaTest do
  use ExUnit.Case

  alias Estuary.Datasets.DatasetSchema

  @table_name Application.get_env(:estuary, :table_name)

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
end
