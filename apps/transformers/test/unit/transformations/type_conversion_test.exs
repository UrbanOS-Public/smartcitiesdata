defmodule Transformers.TypeConversionTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.TypeConversion

  test "when field is nil do nothing" do
    payload = %{"nothing" => nil}
    parameters = %{"field" => "nothing", "sourceType" => "integer", "targetType" => "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, payload} == result
  end

  test "when field is empty string do nothing" do
    payload = %{"nothing" => ""}
    parameters = %{"field" => "nothing", "sourceType" => "string", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"nothing" => nil}} == result
  end

  test "when field is missing return error" do
    payload = %{}
    parameters = %{"field" => "something", "sourceType" => "string", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Missing field in payload: something"} == result
  end

  test "if params do not contain field return error" do
    payload = %{"something" => "some_value"}
    parameters = %{"sourceType" => "string", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, %{"field" => "Missing or empty field"}} == result
  end

  test "if params do not contain source type return error" do
    payload = %{"something" => "some_value"}
    parameters = %{"field" => "something", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, %{"sourceType" => "Missing or empty field"}} == result
  end

  test "if params do not contain target type return error" do
    payload = %{"something" => "some_value"}
    parameters = %{"field" => "something", "sourceType" => "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, %{"targetType" => "Missing or empty field"}} == result
  end

  test "if field supposed to be float but is not, return error" do
    payload = %{"some_float" => "surprise! a string!"}
    parameters = %{"field" => "some_float", "sourceType" => "float", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field some_float not of expected type: float"} == result
  end

  test "if field supposed to be integer but is not, return error" do
    payload = %{"some_int" => "surprise! a string!"}
    parameters = %{"field" => "some_int", "sourceType" => "integer", "targetType" => "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field some_int not of expected type: integer"} == result
  end

  test "if field supposed to be string but is not, return error" do
    payload = %{"some_string" => 1}
    parameters = %{"field" => "some_string", "sourceType" => "string", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Field some_string not of expected type: string"} == result
  end

  test "convert from integer to string" do
    payload = %{"thing" => 300}
    parameters = %{"field" => "thing", "sourceType" => "integer", "targetType" => "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => "300"}} == result
  end

  test "convert from float to string" do
    payload = %{"thing" => 45.67}
    parameters = %{"field" => "thing", "sourceType" => "float", "targetType" => "string"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => "45.67"}} == result
  end

  test "convert from integer to float" do
    payload = %{"thing" => 1}
    parameters = %{"field" => "thing", "sourceType" => "integer", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1.0}} == result
  end

  test "convert from string to float" do
    payload = %{"thing" => "1.12"}
    parameters = %{"field" => "thing", "sourceType" => "string", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1.12}} == result
  end

  test "convert from string to integer" do
    payload = %{"thing" => "1"}
    parameters = %{"field" => "thing", "sourceType" => "string", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1}} == result
  end

  test "convert from float to integer" do
    payload = %{"thing" => 1.0}
    parameters = %{"field" => "thing", "sourceType" => "float", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1}} == result
  end

  test "converting from float to integer rounds up when decimal .5 or higher" do
    payload = %{"thing" => 1.5}
    parameters = %{"field" => "thing", "sourceType" => "float", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 2}} == result
  end

  test "converting from float to integer rounds down when decimal below .5" do
    payload = %{"thing" => 1.4999999}
    parameters = %{"field" => "thing", "sourceType" => "float", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 1}} == result
  end

  test "remember that floating numbers are imprecise" do
    payload = %{"thing" => 1.4999999999999999}
    parameters = %{"field" => "thing", "sourceType" => "float", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:ok, %{"thing" => 2}} == result
  end

  test "if conversion is not supported return error" do
    payload = %{"thing" => true}
    parameters = %{"field" => "thing", "sourceType" => "boolean", "targetType" => "string"}

    {:error, reason} = Transformers.TypeConversion.transform(payload, parameters)

    assert reason == %{
      "sourceType" => "Conversion from boolean to string is not supported",
      "targetType" => "Conversion from boolean to string is not supported"
    }
  end

  test "if string cannot be parsed into integer return error" do
    payload = %{"thing" => "one"}
    parameters = %{"field" => "thing", "sourceType" => "string", "targetType" => "integer"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Cannot parse field thing with value one into integer"} == result
  end

  test "if string cannot be parsed into float return error" do
    payload = %{"thing" => "1/4"}
    parameters = %{"field" => "thing", "sourceType" => "string", "targetType" => "float"}

    result = Transformers.TypeConversion.transform(payload, parameters)

    assert {:error, "Cannot parse field thing with value 1/4 into float"} == result
  end

  describe "validate/1" do
    test "returns :ok if all parameters are present and the type conversion is valid" do
      parameters = %{
        "field" => "some_int",
        "sourceType" => "integer",
        "targetType" => "string"
      }

      {:ok, [field, source_type, target_type, conversion_function]} =
        TypeConversion.validate(parameters)

      assert field == parameters["field"]
      assert source_type == parameters["sourceType"]
      assert target_type == parameters["targetType"]
      assert is_function(conversion_function)
    end

    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "field" => "some_int",
          "sourceType" => "integer",
          "targetType" => "string"
        }
        |> Map.delete(parameter)

      {:error, reason} = TypeConversion.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["field", "sourceType", "targetType"])
    end

    test "if conversion is not supported return error" do
      parameters = %{"field" => "thing", "sourceType" => "boolean", "targetType" => "string"}

      {:error, reasons} = TypeConversion.validate(parameters)

      assert reasons == %{
        "sourceType" => "Conversion from boolean to string is not supported",
        "targetType" => "Conversion from boolean to string is not supported"
      }
    end
  end
end
