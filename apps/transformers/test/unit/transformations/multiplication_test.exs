defmodule Transformers.MultiplicationTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.Multiplication

  describe "The multiplication transform" do
    test "returns payload with target field of a single input multiplicand" do
      params = %{
        "multiplicands" => ["input_number"],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 8
    end

    test "returns payload with target field of the input variable multiplied by a constant" do
      params = %{
        "multiplicands" => ["input_number", 5],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 40
    end

    test "returns payload with target field with a specified target field name" do
      params = %{
        "multiplicands" => ["input_number", 5],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 40
    end

    test "returns payload with a different multiplicands" do
      params = %{
        "multiplicands" => ["some_other_input_number", 9],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 27
    end

    test "returns payload with multiple multiplicands fields" do
      params = %{
        "multiplicands" => ["some_other_input_number", "foo"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3, "foo" => 6}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 18
    end

    test "returns input fields along with output fields" do
      params = %{
        "multiplicands" => ["some_other_input_number", "foo"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3, "foo" => 6}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 18
      {:ok, source_field1} = Map.fetch(transformed_payload, "some_other_input_number")
      assert source_field1 == 3
      {:ok, source_field2} = Map.fetch(transformed_payload, "foo")
      assert source_field2 == 6
    end

    test "returns payload with target field a product of decimal values" do
      params = %{
        "multiplicands" => [12.5433, 2.33],
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 29.225889
    end

    test "returns an error if a field in the multiplicand doesnt exist" do
      params = %{
        "multiplicands" => ["some_other_input_number", "bar"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3}

      {:error, reason} = Transformers.Multiplication.transform(message_payload, params)

      assert reason == "A value cannot be parsed to integer or float: bar"
    end

    test "ignores additional payload fields that are not in the multiplicands" do
      params = %{
        "multiplicands" => ["some_other_input_number", 9],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"input_number" => 8, "some_other_input_number" => 3}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 27
    end

    test "returns an error if a field in the multiplicand is not a number" do
      params = %{
        "multiplicands" => ["some_other_input_number", "invalid"],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"some_other_input_number" => 3, "invalid" => "not a number"}

      {:error, reason} = Transformers.Multiplication.transform(message_payload, params)

      assert reason == "A value cannot be parsed to integer or float: invalid"
    end

    test "performs transformation as normal when condition evaluates to true" do
      params = %{
        "multiplicands" => ["input_number"],
        "targetField" => "output_number",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "input_number",
        "conditionOperation" => "=",
        "targetConditionValue" => "8"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Multiplication.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 8
    end

    test "does nothing when condition evaluates to false" do
      params = %{
        "multiplicands" => ["input_number"],
        "targetField" => "output_number",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "number",
        "sourceConditionField" => "input_number",
        "conditionOperation" => "=",
        "targetConditionValue" => "10"
      }

      message_payload = %{"input_number" => 8}

      result = Transformers.Multiplication.transform(message_payload, params)

      assert result == {:ok, %{"input_number" => 8}}
    end
  end

  describe "validate/1" do
    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "multiplicands" => [1, 2],
          "targetField" => "area_code"
        }
        |> Map.delete(parameter)

      {:error, reason} = Transformers.Multiplication.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["multiplicands", "targetField"])
    end

    data_test "when nil parameter #{parameter} return error" do
      parameters =
        %{
          "multiplicands" => [1, 2],
          "targetField" => "area_code"
        }
        |> Map.replace(parameter, nil)

      {:error, reason} = Transformers.Multiplication.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["multiplicands", "targetField"])
    end

    test "returns error when fields end in ." do
      params = %{
        "multiplicands" => ["input_number."],
        "targetField" => "output_number."
      }

      message_payload = %{"input_number" => 8}

      {:error, reason} = Transformers.Multiplication.transform(message_payload, params)

      assert reason == %{
               "multiplicands" => "Missing or empty child field",
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
          field_label: "Field to populate with product",
          options: nil
        },
        %{
          field_name: "multiplicands",
          field_type: "list",
          field_label: "List of values or fields to multiply together",
          options: nil
        }
      ]

      assert Transformers.Multiplication.fields() == expected_fields
    end
  end
end
