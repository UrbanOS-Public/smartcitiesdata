defmodule Transformers.ArithmeticSubtractTest do
  use ExUnit.Case

  alias Transformers.ArithmeticSubtract

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

      {:ok, result} = ArithmeticSubtract.transform(payload, parameters)

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

      {:ok, result} = ArithmeticSubtract.transform(payload, parameters)

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

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

      assert reason == %{"minuend" => "Missing field"}
    end

    test "if subtrahends is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "targetField" => "target",
        "minuend" => 1
      }

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

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

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

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

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

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

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

      assert reason == "Missing field in payload: target"
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

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

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

      {:error, reason} = ArithmeticSubtract.transform(payload, parameters)

      assert reason == "A value is not a number: target"
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

      assert ArithmeticSubtract.fields() == expected_fields
    end
  end
end
