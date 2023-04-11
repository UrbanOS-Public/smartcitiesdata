defmodule Transformers.AddTest do
  use ExUnit.Case

  alias Transformers.Add

  describe "transform/2" do
    test "sums combination of several fields and numbers" do
      parameters = %{
        "addends" => [1, 2, "firstField", "secondField"],
        "targetField" => "total"
      }

      payload = %{
        "firstField" => 3,
        "secondField" => 4
      }

      {:ok, result} = Add.transform(payload, parameters)

      assert result == %{
               "firstField" => 3,
               "secondField" => 4,
               "total" => 10
             }
    end

    test "if addends are not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target"
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == %{"addends" => "Missing or empty field"}
    end

    test "if addends is an empty array, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target",
        "addends" => []
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == %{"addends" => "Missing or empty field"}
    end

    test "if targetField is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "addends" => [1]
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == %{"targetField" => "Missing or empty field"}
    end

    test "if specified addend is not on payload, return error" do
      payload = %{
        "some_field" => 0
      }

      parameters = %{
        "addends" => ["target"],
        "targetField" => "some_field"
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == "A value cannot be parsed to integer or float: target"
    end

    test "if specified addend is not a number, return error" do
      payload = %{
        "some_field" => 0,
        "target" => "target"
      }

      parameters = %{
        "addends" => ["target"],
        "targetField" => "some_field"
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == "A value cannot be parsed to integer or float: target"
    end

    test "sets target field to addend when given single addend" do
      parameters = %{
        "addends" => [1],
        "targetField" => "target"
      }

      payload = %{
        "target" => 0
      }

      {:ok, result} = Add.transform(payload, parameters)

      assert result == %{"target" => 1}
    end

    test "performs transformation as normal when condition returns true" do
      parameters = %{
        "addends" => [1],
        "targetField" => "target",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "target",
        "conditionOperation" => "=",
        "targetConditionValue" => "0"
      }

      payload = %{
        "target" => 0
      }

      {:ok, result} = Add.transform(payload, parameters)

      assert result == %{"target" => 1}
    end

    test "does not perform transformation when condition fails" do
      parameters = %{
        "addends" => [1],
        "targetField" => "target",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "target",
        "conditionOperation" => "=",
        "targetConditionValue" => "5"
      }

      payload = %{
        "target" => 0
      }

      {:ok, result} = Add.transform(payload, parameters)

      assert result == %{"target" => 0}
    end

    test "if any addends end with a period, return error" do
      payload = %{
        "one" => 3,
        "two" => 4,
        "target" => 0
      }

      parameters = %{
        "addends" => ["one.", "two"],
        "targetField" => "target"
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == %{"addends" => "Missing or empty child field"}
    end

    test "if target end with a period, return error" do
      payload = %{
        "one" => 3,
        "two" => 4,
        "target" => 0
      }

      parameters = %{
        "addends" => ["one", "two."],
        "targetField" => "target."
      }

      {:error, reason} = Add.transform(payload, parameters)

      assert reason == %{
               "addends" => "Missing or empty child field",
               "targetField" => "Missing or empty child field"
             }
    end
  end

  describe "fields/0" do
    test "describes the fields needed for transformation" do
      expected_fields = [
        %{
          field_name: "targetField",
          field_type: "string",
          field_label: "Field to populate with sum",
          options: nil
        },
        %{
          field_name: "addends",
          field_type: "list",
          field_label: "List of values or fields to add together",
          options: nil
        }
      ]

      assert Add.fields() == expected_fields
    end
  end
end
