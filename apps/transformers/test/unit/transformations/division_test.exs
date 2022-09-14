defmodule Transformers.DivisionTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.Division
  alias Decimal

  describe "The division transform" do
    test "returns payload with target field equal to the quotient of a dividend and divisor" do
      params = %{
        "dividend" => 10,
        "divisor" => 2,
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 5
    end

    test "returns payload with target field equal to the quotient of a single input dividend variable and divisor constant" do
      params = %{
        "dividend" => "input_number",
        "divisor" => 2,
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 4
    end

    test "returns payload with target field with a specified target field name" do
      params = %{
        "dividend" => "input_number",
        "divisor" => 2,
        "targetField" => "some_other_output_number"
      }

      message_payload = %{"input_number" => 8}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "some_other_output_number")
      assert actual_target_field == 4
    end

    test "returns payload with target field equal to the quotient of single input dividend constant and single divisor variables" do
      params = %{
        "dividend" => 12,
        "divisor" => "input_number",
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 3}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 4
    end

    test "returns payload with a decimal in the target field equal to the quotient of dividend decimal constant and divisor decimal constant" do
      params = %{
        "dividend" => 12.71,
        "divisor" => 3.1,
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 4.1
    end

    test "delete me" do
      Decimal.from_float(12.73)
    end

    test "returns input fields along with output fields" do
      params = %{
        "dividend" => 42,
        "divisor" => "input_number",
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 3}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 14
      {:ok, source_field1} = Map.fetch(transformed_payload, "input_number")
      assert source_field1 == 3
    end

    test "ignores additional payload fields that are not in the dividends or divisors" do
      params = %{
        "dividend" => "some_dividend",
        "divisor" => "input_number",
        "targetField" => "output_number"
      }

      message_payload = %{"input_number" => 3, "some_dividend" => 9, "foo" => 8}

      {:ok, transformed_payload} = Division.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "output_number")
      assert actual_target_field == 3
      {:ok, foo_field} = Map.fetch(transformed_payload, "foo")
      assert foo_field == 8
    end

    test "returns an error if a field in the dividend doesnt exist" do
      params = %{
        "dividend" => "not_valid",
        "divisor" => 7,
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:error, reason} = Division.transform(message_payload, params)

      assert reason == "Missing field in payload: not_valid"
    end

    test "returns an error if a field in the divisor doesnt exist" do
      params = %{
        "dividend" => 9,
        "divisor" => "not_valid",
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:error, reason} = Division.transform(message_payload, params)

      assert reason == "Missing field in payload: not_valid"
    end

    test "returns an error if a field in the dividend is not a number" do
      params = %{
        "dividend" => "invalid",
        "divisor" => 9,
        "targetField" => "output_number"
      }

      message_payload = %{"invalid" => "not a number"}

      {:error, reason} = Division.transform(message_payload, params)

      assert reason == "payload field is not a number: invalid"
    end

    test "returns an error if a field in the divisor is not a number" do
      params = %{
        "dividend" => 9,
        "divisor" => "invalid",
        "targetField" => "output_number"
      }

      message_payload = %{"invalid" => "not a number"}

      {:error, reason} = Division.transform(message_payload, params)

      assert reason == "payload field is not a number: invalid"
    end

    test "returns an error if the divisor is 0" do
      params = %{
        "dividend" => 9,
        "divisor" => 0,
        "targetField" => "output_number"
      }

      message_payload = %{}

      {:error, reason} = Transformers.Division.transform(message_payload, params)

      assert reason == "divisor cannot be equal to 0"
    end
  end

  describe "validate_parameters/1" do
    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "dividend" => 9,
          "divisor" => "invalid",
          "targetField" => "output_number"
        }
        |> Map.delete(parameter)

      {:error, reason} = Division.validate_parameters(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["dividend", "divisor", "targetField"])
    end

    data_test "when parameter #{parameter} is nil return error" do
      parameters =
        %{
          "dividend" => 9,
          "divisor" => "invalid",
          "targetField" => "output_number"
        }
        |> Map.put(parameter, nil)

      {:error, reason} = Division.validate_parameters(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["dividend", "divisor", "targetField"])
    end

    test "when targetField is empty string return error" do
      parameters = %{
        "dividend" => 9,
        "divisor" => "invalid",
        "targetField" => ""
      }

      {:error, reason} = Division.validate_parameters(parameters)

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
          field_name: "dividend",
          field_type: "string or number",
          field_label: "A field or number that will be used as the number being divided",
          options: nil
        },
        %{
          field_name: "divisor",
          field_type: "string or number",
          field_label: "A field or number that will be used as the number to divide by",
          options: nil
        }
      ]

      assert Division.fields() == expected_fields
    end
  end
end
