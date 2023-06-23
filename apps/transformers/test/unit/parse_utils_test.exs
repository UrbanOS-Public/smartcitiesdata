defmodule Transformers.ParseUtilsTest do
  use ExUnit.Case

  alias Transformers.ParseUtils

  describe "parseValue/2" do
    test "when value is number, return ok tuple with number" do
      value = 1

      result = ParseUtils.parseValue(value, %{})

      assert result == {:ok, value}
    end

    test "when value is an integer string, return ok tuple with integer" do
      value = "1"
      numericValue = 1

      result = ParseUtils.parseValue(value, %{})

      assert result == {:ok, numericValue}
    end

    test "when value is a float string, return ok tuple with float" do
      value = "1.0"
      numericValue = 1.0

      result = ParseUtils.parseValue(value, %{})

      assert result == {:ok, numericValue}
    end

    test "when value is part of the payload, return ok tuple with payload value" do
      value = "key"

      payload = %{
        "key" => 1.0
      }

      result = ParseUtils.parseValue(value, payload)

      assert result == {:ok, payload["key"]}
    end

    test "when value cannot be parsed, return error" do
      value = "badValue"

      result = ParseUtils.parseValue(value, %{})

      assert result ==
               {:error,
                "A given value badValue cannot be parsed to integer or float"}
    end
  end

  describe "parseValues/2" do
    test "when all numeric list is given, returns ok tuple with numeric list" do
      list = [1, 2, 3]

      result = ParseUtils.parseValues(list, %{})

      assert result == {:ok, list}
    end

    test "when given list contains numeric parseable strings, returns ok tuple with numeric list" do
      list = [1, "2", 3]
      numericList = [1, 2, 3]

      result = ParseUtils.parseValues(list, %{})

      assert result == {:ok, numericList}
    end

    test "when given list contains payload parseable strings, returns ok tuple with numeric list" do
      list = [1, "key", 3]

      payload = %{
        "key" => 2.0
      }

      numericList = [1, 2.0, 3]

      result = ParseUtils.parseValues(list, payload)

      assert result == {:ok, numericList}
    end

    test "when list contains non-parsable strings, returns error tuple with reason" do
      list = [1, "badValue", 3]

      result = ParseUtils.parseValues(list, %{})

      assert result ==
               {:error,
                "A given value badValue cannot be parsed to integer or float"}
    end
  end

  describe "operandsToNumbers/2" do
    test "when called with list, returns ok tuple with numeric list" do
      list = [1, "2", "key"]

      payload = %{
        "key" => 3.0
      }

      numericList = [1, 2, 3.0]

      result = ParseUtils.operandsToNumbers(list, payload)

      assert result == {:ok, numericList}
    end

    test "when called with string representation of list, returns ok tuple with numeric list" do
      list = "1, 2.0, key"

      payload = %{
        "key" => 3.0
      }

      numericList = [1, 2.0, 3.0]

      result = ParseUtils.operandsToNumbers(list, payload)

      assert result == {:ok, numericList}
    end

    test "when called with unparsable string representation of list, returns error tuple with reason" do
      list = "badValue"

      result = ParseUtils.operandsToNumbers(list, %{})

      assert result ==
               {:error,
                "A given value badValue cannot be parsed to integer or float"}
    end

    test "when called with non-binary and non-list operands, returns error tuple with reason" do
      result = ParseUtils.operandsToNumbers(1, %{})

      assert result ==
               {:error,
                "Operands must be a list of values or a string representation of a list of values"}
    end
  end
end
