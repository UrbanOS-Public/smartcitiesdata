defmodule Transformers.Validations.ValidRegexTest do
  use ExUnit.Case

  alias Transformers.Validations.ValidRegex
  alias Transformers.Validations.ValidationStatus

  test "add value if regex compiles" do
    status = %ValidationStatus{}
    field = "regex"
    value = "gr[ae]y"
    parameters = %{field => value}

    result = ValidRegex.check(status, parameters, field)

    assert result.values == %{"regex" => ~r/gr[ae]y/}
  end

  test "add error if regex does not compile" do
    status = %ValidationStatus{}
    field = "regex"
    value = "(()"
    parameters = %{field => value}

    result = ValidRegex.check(status, parameters, field)

    assert result.errors == %{"regex" => "Invalid regular expression: missing ) at index 3"}
  end

  test "add error if no value provided" do
    status = %ValidationStatus{}
    field = "regex"
    parameters = %{field => nil}

    result = ValidRegex.check(status, parameters, field)

    assert result.errors == %{"regex" => "No regular expression provided"}
  end
end
