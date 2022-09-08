defmodule Transformers.DivisionTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.Division
  alias Decimal, as: D

  describe "The division transform" do
    test "returns payload with target field equal to the quotient of a dividend and divisor" do
      params = %{
        "dividends" => 10,
        "divisors" => 2,
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == D.new(5)
    end

    test "returns payload with target field equal to the quotient of a single input dividend variable and divisor constant" do
      params = %{
        "dividends" => ["input_number"],
        "divisors" => [2],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == D.new(4)
    end

    test "returns payload with target field with a specified target field name" do
      params = %{
        "dividends" => ["input_number"],
        "divisors" => [2],
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == D.new(4)
    end

#    test "returns payload with target field equal to the quotient of multiple input dividend variable and divisor constant" do
#      params = %{
#        "dividends" => ["input_number", "foo"],
#        "divisors" => [2],
#        "targetField" => "output_number"
#      }
#
#      message_payload = %{"input_number" => 3, "foo" => 6}
#
#      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)
#
#      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
#      assert actual_target_field == D.new(.0)
#    end

    test "returns payload with target field equal to the quotient of single input dividend constant and single divisor variables" do
      params = %{
        "dividends" => [12],
        "divisors" => ["input_number"],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 3}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == D.new(4)
    end

    test "returns payload with a decimal in the target field equal to the quotient of dividend decimal constant and divisor decimal constant" do
      params = %{
        "dividends" => [12.71],
        "divisors" => [3.1],
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == D.new(4.1)
    end

#    test "returns payload with target field equal to the quotient of single input dividend constant and multiple divisor variables" do
#      params = %{
#        "dividends" => [42],
#        "divisors" => ["input_number", "foo"],
#        "targetField" => "output_number"
#      }
#
#      message_payload = %{"input_number" => 3, "foo" => 7}
#
#      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)
#
#      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
#      assert actual_target_field == D.new(.0)
#    end

    test "returns input fields along with output fields" do
      params = %{
        "dividends" => [42],
        "divisors" => ["input_number", 7],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 3}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == D.new(2)
      {:ok, source_field1} = Map.fetch(transformed_payload, "input_number")
      assert source_field1 == 3
    end

    test "ignores additional payload fields that are not in the dividends or divisors" do
      params = %{
        "dividends" => ["some_dividend"],
        "divisors" => ["input_number"],
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 3, "some_dividend" => 9, "foo" => 8}

      {:ok, transformed_payload} = Transformers.Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == D.new(3)
      {:ok, foo_field} = Map.fetch(transformed_payload, "foo")
      assert foo_field == 8
    end

    test "returns an error if a field in the dividend doesnt exist" do
      params = %{
        "dividends" => ["not_valid"],
        "divisors" => [7],
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:error, reason} = Transformers.Division.transform(message_payload, params)

      assert reason == "Missing field in payload: not_valid"
    end

    test "returns an error if a field in the divisor doesnt exist" do
      params = %{
        "dividends" => [9],
        "divisors" => ["not_valid"],
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:error, reason} = Transformers.Division.transform(message_payload, params)

      assert reason == "Missing field in payload: not_valid"
    end

    test "returns an error if a field in the dividend is not a number" do
      params = %{
        "dividends" => ["invalid"],
        "divisors" => [9],
        "targetField" => "output_number"
      }

      message_payload = %{"invalid" => "not a number"}

      {:error, reason} = Transformers.Division.transform(message_payload, params)

      assert reason == "payload field is not a number: invalid"
    end

    test "returns an error if a field in the divisor is not a number" do
      params = %{
        "dividends" => [9],
        "divisors" => ["invalid"],
        "targetField" => "output_number"
      }

      message_payload = %{"invalid" => "not a number"}

      {:error, reason} = Transformers.Division.transform(message_payload, params)

      assert reason == "payload field is not a number: invalid"
    end

#    test "returns an error if the divisor is 0" do
#      params = %{
#        "dividends" => [9],
#        "divisors" => [0],
#        "targetField" => "output_number"
#      }
#
#      message_payload = %{}
#
#      {:error, reason} = Transformers.Division.transform(message_payload, params)
#
#      assert reason == "divisor is 0"
#    end
  end

  describe "validate/1" do
    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "dividends" => [9],
          "divisors" => ["invalid"],
          "targetField" => "output_number"
        }
        |> Map.delete(parameter)

      {:error, reason} = Transformers.Division.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["dividends", "divisors", "targetField"])
    end

    data_test "when parameter #{parameter} is nil return error" do
      parameters =
        %{
          "dividends" => [9],
          "divisors" => ["invalid"],
          "targetField" => "output_number"
        }
        |> Map.replace(parameter, nil)

      {:error, reason} = Transformers.Division.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["dividends", "divisors", "targetField"])
    end

    data_test "when parameter #{parameter} is empty list return error" do
      parameters =
        %{
          "dividends" => [9],
          "divisors" => ["invalid"],
          "targetField" => "output_number"
        }
        |> Map.replace(parameter, [])

      {:error, reason} = Transformers.Division.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["dividends", "divisors"])
    end

    test "when targetField is empty string return error" do
      parameters = %{
        "dividends" => [9],
        "divisors" => ["invalid"],
        "targetField" => ""
      }

      {:error, reason} = Transformers.Division.validate(parameters)

      assert reason == %{"targetField" => "Missing or empty field"}
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
          field_name: "dividends",
          field_type: "list",
          field_label:
            "List of values or fields, multiplied together, that will be used as the number being divided",
          options: nil
        },
        %{
          field_name: "divisors",
          field_type: "list",
          field_label:
            "List of values or fields, multiplied together, that will be used as the number to divide by",
          options: nil
        }
      ]

      assert Transformers.Division.fields() == expected_fields
    end
  end
end
