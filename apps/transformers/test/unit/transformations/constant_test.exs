defmodule Transformers.ConstantTest do
  use ExUnit.Case

  alias Transformers.Constant

  describe "transform" do
    test "replaces field value with new supplied value" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "string"
      }

      payload = %{
        "testField" => "old value"
      }

      {:ok, result} = Constant.transform(payload, parameters)

      assert result == %{
        "testField" => "new value"
      }
    end

    test "creates new field when target field is different" do
      parameters = %{
        "targetField" => "testField2",
        "newValue" => "new value",
        "valueType" => "string"
      }

      payload = %{
        "testField" => "old value"
      }

      {:ok, result} = Constant.transform(payload, parameters)

      assert result == %{
        "testField" => "old value",
        "testField2" => "new value"
      }
    end

    test "converts value to integer type" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "1",
        "valueType" => "integer"
      }

      payload = %{
        "testField" => "old value"
      }

      {:ok, result} = Constant.transform(payload, parameters)

      assert result == %{
        "testField" => 1
      }
    end

    test "converts value to float type" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "1",
        "valueType" => "float"
      }

      payload = %{
        "testField" => "old value"
      }

      {:ok, result} = Constant.transform(payload, parameters)

      assert result == %{
        "testField" => 1.0
      }
    end
  end

  describe "error handling" do
    test "returns error when invalid type is provided" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "new value",
        "valueType" => "nonetype"
      }

      payload = %{
        "testField" => "old value"
      }

      {:error, result} = Constant.transform(payload, parameters)

      assert result == "Error: Invalid conversion type: nonetype"
    end

    test "returns error when providing value that cannot be converted to type" do
      parameters = %{
        "targetField" => "testField",
        "newValue" => "flooooaaaat",
        "valueType" => "float"
      }

      payload = %{
        "testField" => "old value"
      }

      {:error, result} = Constant.transform(payload, parameters)

      assert result == "Error: could not convert 'flooooaaaat' to type: float"
    end
  end
end
