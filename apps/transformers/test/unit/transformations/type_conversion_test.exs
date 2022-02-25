defmodule Transformers.TypeConversionTest do
  use ExUnit.Case

  test "when field is nil do nothing" do
    payload = %{"nothing" => nil}
    parameters = %{field: "nothing", sourceType: "integer", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert payload == result
  end

  test "when field is empty string do nothing" do
    payload = %{"nothing" => ""}
    parameters = %{field: "nothing", sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert %{"nothing" => nil} == result
  end

  test "when field is missing return error" do
    payload = %{}
    parameters = %{field: "something", sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field to convert does not exist in message"} == result
  end

  test "if params do not contain field return error" do
    payload = %{"something" => "some_value"}
    parameters = %{sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Missing transformation parameter: field"} == result
  end
end
