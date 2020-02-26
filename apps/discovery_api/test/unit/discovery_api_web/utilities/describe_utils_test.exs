defmodule DiscoveryApiWeb.Utilities.DescribeUtilsTest do
  use ExUnit.Case
  alias DiscoveryApiWeb.Utilities.DescribeUtils

  describe "convert_description/1" do
    test "converts a table description to a schema" do
      query_description = [
        %{
          "Column Name" => "a",
          "Type" => "integer"
        },
        %{
          "Column Name" => "b",
          "Type" => "integer"
        }
      ]

      expected_schema = [
        %{
          name: "a",
          type: "integer"
        },
        %{
          name: "b",
          type: "integer"
        }
      ]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema
    end

    test "converts bigints to longs and varchars to strings" do
      query_description = [
        %{
          "Column Name" => "a",
          "Type" => "bigint"
        },
        %{
          "Column Name" => "b",
          "Type" => "varchar"
        }
      ]

      expected_schema = [
        %{
          name: "a",
          type: "long"
        },
        %{
          name: "b",
          type: "string"
        }
      ]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema
    end

    test "converts arrays and rows to 'nested'" do
      query_description = [
        %{
          "Column Name" => "a",
          "Type" => "row(vehicle_id varchar)"
        },
        %{
          "Column Name" => "b",
          "Type" => "array(varchar)"
        }
      ]

      expected_schema = [
        %{
          name: "a",
          type: "nested"
        },
        %{
          name: "b",
          type: "nested"
        }
      ]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema
    end
  end
end
