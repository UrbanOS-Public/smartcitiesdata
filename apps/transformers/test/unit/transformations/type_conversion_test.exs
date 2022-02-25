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

    assert {:error, "Missing field in payload: something"} == result
  end

  test "if params do not contain field return error" do
    payload = %{"something" => "some_value"}
    parameters = %{sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Missing transformation parameter: field"} == result
  end

  test "if params do not contain source type return error" do
    payload = %{"something" => "some_value"}
    parameters = %{field: "something", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Missing transformation parameter: sourceType"} == result
  end

  test "if params do not contain target type return error" do
    payload = %{"something" => "some_value"}
    parameters = %{field: "something", sourceType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Missing transformation parameter: targetType"} == result
  end

  test "if field supposed to be float but is not, return error" do
    payload = %{"some_float" => "surprise! a string!"}
    parameters = %{field: "some_float", sourceType: "float", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field some_float not of expected type: float"} == result
  end

  test "if field supposed to be integer but is not, return error" do
    payload = %{"some_int" => "surprise! a string!"}
    parameters = %{field: "some_int", sourceType: "integer", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field some_int not of expected type: integer"} == result
  end

  test "if field supposed to be string but is not, return error" do
    payload = %{"some_string" => 1}
    parameters = %{field: "some_string", sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field some_string not of expected type: string"} == result
  end

  test "convert from integer to string" do
    payload = %{"thing" => 300}
    parameters = %{field: "thing", sourceType: "integer", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert %{"thing" => "300"} == result
  end
end
