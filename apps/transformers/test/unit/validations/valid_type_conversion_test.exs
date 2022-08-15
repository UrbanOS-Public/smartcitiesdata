defmodule Transformers.Validations.ValidTypeConversionTest do
  use ExUnit.Case

  alias Transformers.ConversionFunctions
  alias Transformers.Validations.ValidTypeConversion
  alias Transformers.Validations.ValidationStatus

  test "if source has prior error do nothing" do
    parameters = %{"sourceType" => "string", "targetType" => "integer"}

    original =
      %ValidationStatus{}
      |> ValidationStatus.add_error("sourceType", "something bad happened")

    result =
      ValidTypeConversion.check(
        original,
        parameters,
        "sourceType",
        "targetType",
        "function_field"
      )

    assert result == original
  end

  test "if target has prior error do nothing" do
    parameters = %{"sourceType" => "string", "targetType" => "integer"}

    original =
      %ValidationStatus{}
      |> ValidationStatus.add_error("targetType", "something bad happened")

    result =
      ValidTypeConversion.check(
        original,
        parameters,
        "sourceType",
        "targetType",
        "function_field"
      )

    assert result == original
  end

  test "adds error to source and target if unsupported conversion" do
    parameters = %{"sourceType" => "double", "targetType" => "float"}

    result =
      %ValidationStatus{}
      |> ValidTypeConversion.check(parameters, "sourceType", "targetType", "function_field")

    expected_message = "Conversion from double to float is not supported"
    assert result.errors == %{"sourceType" => expected_message, "targetType" => expected_message}
  end

  test "if conversion supported then add function to specified field" do
    parameters = %{"origin" => "integer", "destination" => "float"}

    result =
      %ValidationStatus{}
      |> ValidTypeConversion.check(parameters, "origin", "destination", "thing_to_do")

    {:ok, expected_function} = ConversionFunctions.pick("integer", "float")
    assert ValidationStatus.get_value(result, "thing_to_do") == expected_function
  end
end
