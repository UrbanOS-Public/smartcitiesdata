defmodule DiscoveryApiWeb.Utilities.DescribeUtilsTest do
  use ExUnit.Case
  import Checkov
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
          id: "a",
          description: "a",
          dataType: "integer"
        },
        %{
          id: "b",
          description: "b",
          dataType: "integer"
        }
      ]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema
    end

    test "converts a table description's name to a tableau compliant id" do
      query_description = [
        %{
          "Column Name" => "ab-ba",
          "Type" => "integer"
        }
      ]

      expected_schema = [
        %{
          id: "ab_ba",
          description: "ab-ba",
          dataType: "integer"
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
          id: "a",
          description: "a",
          dataType: "long"
        },
        %{
          id: "b",
          description: "b",
          dataType: "string"
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
          id: "a",
          description: "a",
          dataType: "nested"
        },
        %{
          id: "b",
          description: "b",
          dataType: "nested"
        }
      ]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema
    end

    data_test "converts #{dataType} to itself" do
      query_description = [%{"Column Name" => "a", "Type" => dataType}]
      expected_schema = [%{id: "a", description: "a", dataType: dataType}]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema

      where(dataType: ["integer", "decimal", "double", "float", "boolean", "date", "timestamp"])
    end

    data_test "converts unhandled dataType #{dataType} to string" do
      query_description = [%{"Column Name" => "a", "Type" => dataType}]
      expected_schema = [%{id: "a", description: "a", dataType: "string"}]

      actual_schema = DescribeUtils.convert_description(query_description)
      assert actual_schema == expected_schema

      where(dataType: ["bob", "#baddataType", "timestamp with time zone"])
    end
  end
end
