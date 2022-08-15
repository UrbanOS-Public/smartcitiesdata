defmodule Transformers.Validations.DateTimeFormatTest do
  use ExUnit.Case

  alias Transformers.Validations.DateTimeFormat
  alias Transformers.Validations.ValidationStatus

  test "adds value to status values if valid" do
    status = %ValidationStatus{}
    key = "format"
    value = "{YYYY}-{0M}-{D} {h24}:{m}"
    parameters = %{key => value}

    result = DateTimeFormat.check(status, parameters, key)

    assert ValidationStatus.get_value(result, key) == value
  end

  test "adds message to errors if invalid" do
    status = %ValidationStatus{}
    key = "format"
    value = "{invalid}"
    parameters = %{key => value}

    result = DateTimeFormat.check(status, parameters, key)

    expected_message =
      "DateTime format \"{invalid}\" is invalid: Expected at least one parser to succeed at line 1, column 0."

    assert ValidationStatus.get_error(result, key) == expected_message
  end

  test "add error for missing value if nil" do
    status = %ValidationStatus{}
    key = "format"
    parameters = %{key => nil}

    result = DateTimeFormat.check(status, parameters, key)

    expected_message = "No datetime format provided"
    assert ValidationStatus.get_error(result, key) == expected_message
  end
end
