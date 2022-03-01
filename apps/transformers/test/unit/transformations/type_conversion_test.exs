defmodule Transformers.TypeConversionTest do
  use ExUnit.Case

  test "when field is nil do nothing" do
    payload = %{"nothing" => nil}
    parameters = %{field: "nothing", sourceType: "integer", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, payload} == result
  end

  test "when field is empty string do nothing" do
    payload = %{"nothing" => ""}
    parameters = %{field: "nothing", sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"nothing" => nil}} == result
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

    assert {:ok, %{"thing" => "300"}} == result
  end

  test "convert from float to string" do
    payload = %{"thing" => 45.67}
    parameters = %{field: "thing", sourceType: "float", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => "45.67"}} == result
  end

  test "convert from integer to float" do
    payload = %{"thing" => 1}
    parameters = %{field: "thing", sourceType: "integer", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1.0}} == result
  end

  test "convert from string to float" do
    payload = %{"thing" => "1.12"}
    parameters = %{field: "thing", sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1.12}} == result
  end

  test "convert from string to integer" do
    payload = %{"thing" => "1"}
    parameters = %{field: "thing", sourceType: "string", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1}} == result
  end

  test "convert from float to integer" do
    payload = %{"thing" => 1.0}
    parameters = %{field: "thing", sourceType: "float", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1}} == result
  end

  test "converting from float to integer rounds up when decimal .5 or higher" do
    payload = %{"thing" => 1.5}
    parameters = %{field: "thing", sourceType: "float", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 2}} == result
  end

  test "converting from float to integer rounds down when decimal below .5" do
    payload = %{"thing" => 1.4999999}
    parameters = %{field: "thing", sourceType: "float", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1}} == result
  end

  test "remember that floating numbers are imprecise" do
    payload = %{"thing" => 1.4999999999999999}
    parameters = %{field: "thing", sourceType: "float", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 2}} == result
  end

  test "if conversion is not supported return error" do
    payload = %{"thing" => true}
    parameters = %{field: "thing", sourceType: "boolean", targetType: "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Conversion from boolean to string is not supported"} == result
  end

  test "if string cannot be parsed into integer return error" do
    payload = %{"thing" => "one"}
    parameters = %{field: "thing", sourceType: "string", targetType: "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Cannot parse field thing with value one into integer"} == result
  end

  test "if string cannot be parsed into float return error" do
    payload = %{"thing" => "1/4"}
    parameters = %{field: "thing", sourceType: "string", targetType: "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Cannot parse field thing with value 1/4 into float"} == result
  end
end
