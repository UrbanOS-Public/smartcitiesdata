defmodule Transformers.SubtractTest do
  use ExUnit.Case

  alias Transformers.Subtract

  describe "transform/2" do
    test "subtracts combination of several fields and numbers from minuend" do
      parameters = %{
        "minuend" => "firstTotal",
        "subtrahends" => [1, 2, "firstField", "secondField"],
        "targetField" => "lastTotal"
      }

      payload = %{
        "firstTotal" => 20,
        "firstField" => 3,
        "secondField" => 4
      }

      {:ok, result} = Subtract.transform(payload, parameters)

      assert result == %{
               "firstTotal" => 20,
               "firstField" => 3,
               "secondField" => 4,
               "lastTotal" => 10
             }
    end

    test "subtracts combination of several fields and numbers from numerical minuend" do
      parameters = %{
        "minuend" => 20,
        "subtrahends" => [1, 22, "firstField", "secondField"],
        "targetField" => "lastTotal"
      }

      payload = %{
        "firstField" => 3,
        "secondField" => 4
      }

      {:ok, result} = Subtract.transform(payload, parameters)

      assert result == %{
               "firstField" => 3,
               "secondField" => 4,
               "lastTotal" => -10
             }
    end

    test "if minuend is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target",
        "subtrahends" => [1]
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason == %{"minuend" => "Missing or empty field"}
    end

    test "if subtrahends is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target",
        "minuend" => 1
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason == %{"subtrahends" => "Missing or empty field"}
    end

    test "if subtrahends is an empty array, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target",
        "subtrahends" => [],
        "minuend" => 1
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason == %{"subtrahends" => "Missing or empty field"}
    end

    test "if targetField is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "subtrahends" => [1],
        "minuend" => 1
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason == %{"targetField" => "Missing or empty field"}
    end

    test "if specified subtrahend is not on payload, return error" do
      payload = %{
        "not_target" => 1
      }

      parameters = %{
        "subtrahends" => ["target"],
        "minuend" => 1,
        "targetField" => "some_field"
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason ==
               "A given value target cannot be parsed to integer or float, nor is it in the following payload: %{\"not_target\" => 1}}"
    end

    test "if specified minuend is not on payload, return error" do
      payload = %{
        "not_minuend" => 0
      }

      parameters = %{
        "subtrahends" => [1],
        "minuend" => "minuend",
        "targetField" => "target"
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason == "Missing field in payload: minuend"
    end

    test "if specified subtrahend is not a number, return error" do
      payload = %{
        "some_field" => 0,
        "target" => "target"
      }

      parameters = %{
        "subtrahends" => ["target"],
        "minuend" => 1,
        "targetField" => "some_field"
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason ==
               "A given value target cannot be parsed to integer or float, nor is it in the following payload: %{\"some_field\" => 0, \"target\" => \"target\"}}"
    end

    test "performs transformation as normal when condition evaluates to true" do
      parameters = %{
        "minuend" => "firstTotal",
        "subtrahends" => [1, 2, "firstField", "secondField"],
        "targetField" => "lastTotal",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "firstTotal",
        "conditionOperation" => "=",
        "targetConditionValue" => "20"
      }

      payload = %{
        "firstTotal" => 20,
        "firstField" => 3,
        "secondField" => 4
      }

      {:ok, result} = Subtract.transform(payload, parameters)

      assert result == %{
               "firstTotal" => 20,
               "firstField" => 3,
               "secondField" => 4,
               "lastTotal" => 10
             }
    end

    test "does nothing when condition evaluates to false" do
      parameters = %{
        "minuend" => "firstTotal",
        "subtrahends" => [1, 2, "firstField", "secondField"],
        "targetField" => "lastTotal",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "firstTotal",
        "conditionOperation" => "=",
        "targetConditionValue" => "7"
      }

      payload = %{
        "firstTotal" => 20,
        "firstField" => 3,
        "secondField" => 4
      }

      {:ok, result} = Subtract.transform(payload, parameters)

      assert result == %{
               "firstTotal" => 20,
               "firstField" => 3,
               "secondField" => 4
             }
    end

    test "if parameters ends in ., return error" do
      payload = %{
        "some_field" => 0,
        "target" => "target"
      }

      parameters = %{
        "subtrahends" => ["target."],
        "minuend" => 1,
        "targetField" => "some_field.some_child.some_field"
      }

      {:error, reason} = Subtract.transform(payload, parameters)

      assert reason == %{"subtrahends" => "Missing or empty child field"}
    end

    test "subtracts from all values in list" do
      parameters = %{
        "minuend" => "firstTotal",
        "subtrahends" => ["parent_list[*].subtrahends"],
        "targetField" => "lastTotal"
      }

      payload = %{
        "firstTotal" => 20,
        "parent_list[0].subtrahends" => 1,
        "parent_list[2].subtrahends" => 1,
        "parent_list[3].subtrahends" => 1,
        "parent_list[4].subtrahends" => 1,
        "parent_list[5].subtrahends" => 1,
        "parent_list[6].subtrahends" => 1,
        "secondField" => 4
      }

      {:ok, result} = Subtract.transform(payload, parameters)

      assert result == %{
               "firstTotal" => 20,
               "parent_list[0].subtrahends" => 1,
               "parent_list[2].subtrahends" => 1,
               "parent_list[3].subtrahends" => 1,
               "parent_list[4].subtrahends" => 1,
               "parent_list[5].subtrahends" => 1,
               "parent_list[6].subtrahends" => 1,
               "secondField" => 4,
               "lastTotal" => 14
             }
    end
  end

  describe "fields/0" do
    test "describes the fields needed for transformation" do
      expected_fields = [
        %{
          field_name: "targetField",
          field_type: "string",
          field_label: "Field to populate with difference",
          options: nil
        },
        %{
          field_name: "subtrahends",
          field_type: "list",
          field_label: "List of values or fields to subtract from minuend",
          options: nil
        },
        %{
          field_name: "minuend",
          field_type: "string",
          field_label: "Field to subtract from",
          options: nil
        }
      ]

      assert Subtract.fields() == expected_fields
    end
  end
end
