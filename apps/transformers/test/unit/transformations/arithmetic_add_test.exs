defmodule Transformers.ArithmeticAddTest do
  use ExUnit.Case

  alias Transformers.ArithmeticAdd

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

      {:ok, result} = ArithmeticAdd.transform(payload, parameters)

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

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

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

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == %{"addends" => "Missing or empty field"}
    end

    test "if targetField is not specified, return error" do
      payload = %{
        "target" => 0
      }

      parameters = %{
        "addends" => [1]
      }

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

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

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == "Missing field in payload: target"
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

      {:error, reason} = ArithmeticAdd.transform(payload, parameters)

      assert reason == "A value is not a number: target"
    end

    test "sets target field to addend when given single addend" do
      parameters = %{
        "addends" => [1],
        "targetField" => "target"
      }

      payload = %{
        "target" => 0
      }

      {:ok, result} = ArithmeticAdd.transform(payload, parameters)

      assert result == %{"target" => 1}
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

      assert ArithmeticAdd.fields() == expected_fields
    end
  end
end
