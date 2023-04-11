defmodule Transformers.ConcatenationTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.Concatenation

  describe "transform/2" do
    data_test "when missing parameter #{parameter} return error #{message}" do
      payload = %{
        "string1" => "one",
        "string2" => "two"
      }

      parameters =
        %{
          "sourceFields" => "name, last_name",
          "separator" => ".",
          "targetField" => "full_name"
        }
        |> Map.delete(parameter)

      {:error, reason} = Concatenation.transform(payload, parameters)

      assert reason == %{"#{parameter}" => "#{message}"}

      where(
        parameter: ["sourceFields", "separator", "targetField"],
        message: ["Missing or empty field", "Missing or empty field", "Missing or empty field"]
      )
    end

    test "error if a source field is missing" do
      payload = %{
        "first_name" => "Sam"
      }

      parameters = %{
        "sourceFields" => "first_name, middle_initial, last_name",
        "separator" => ".",
        "targetField" => "full_name"
      }

      {:error, reason} = Concatenation.transform(payload, parameters)

      assert reason == "Missing field in payload: [middle_initial, last_name]"
    end

    test "return error if source fields not a list" do
      payload = %{
        "name" => "one",
        "name2" => "two"
      }

      parameters = %{
        "sourceFields" => "name",
        "separator" => ".",
        "targetField" => "full_name"
      }

      {:error, reason} = Concatenation.transform(payload, parameters)

      assert reason == "Expected list but received single value: sourceFields"
    end

    test "concatenate string fields into new field" do
      payload = %{
        "first_name" => "Sam",
        "middle_initial" => "I",
        "last_name" => "Am"
      }

      parameters = %{
        "sourceFields" => "first_name, middle_initial, last_name",
        "separator" => ".",
        "targetField" => "full_name"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert "Sam.I.Am" == Map.get(result, "full_name")
      assert "Sam" == Map.get(result, "first_name")
      assert "I" == Map.get(result, "middle_initial")
      assert "Am" == Map.get(result, "last_name")
    end

    test "concatenate string fields into existing field" do
      payload = %{
        "name" => "Sam",
        "middle_initial" => "I",
        "last_name" => "Am"
      }

      parameters = %{
        "sourceFields" => "name, middle_initial, last_name",
        "separator" => ".",
        "targetField" => "name"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert "Sam.I.Am" == Map.get(result, "name")
      assert "I" == Map.get(result, "middle_initial")
      assert "Am" == Map.get(result, "last_name")
    end

    test "concatenating an empty string works as expected" do
      payload = %{
        "name" => "Sam",
        "other" => ""
      }

      parameters = %{
        "sourceFields" => "name, other",
        "separator" => ".",
        "targetField" => "name"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert "Sam." == Map.get(result, "name")
      assert "" == Map.get(result, "other")
    end

    test "concatenating with nil works like empty string" do
      payload = %{
        "name" => "Sam",
        "other" => nil
      }

      parameters = %{
        "sourceFields" => "name, other",
        "separator" => ".",
        "targetField" => "name"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert "Sam." == Map.get(result, "name")
      assert nil == Map.get(result, "other")
    end

    test "converts integers to strings before concatenating" do
      payload = %{
        "other" => 123,
        "name" => "Sam"
      }

      parameters = %{
        "sourceFields" => "other, name",
        "separator" => ".",
        "targetField" => "name"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert "123.Sam" == Map.get(result, "name")
    end

    test "returns error if a source field cannot be converted to string" do
      payload = %{
        "other" => {:ok, "Hello"},
        "name" => "Sam"
      }

      parameters = %{
        "sourceFields" => "other, name",
        "separator" => ".",
        "targetField" => "name"
      }

      {:error, result} = Concatenation.transform(payload, parameters)

      assert result == "Could not convert all source fields into strings"
    end

    test "performs transform as normal when condition evaluates to true" do
      payload = %{
        "first_name" => "Sam",
        "middle_initial" => "I",
        "last_name" => "Am"
      }

      parameters = %{
        "sourceFields" => "first_name, middle_initial, last_name",
        "separator" => ".",
        "targetField" => "full_name",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "first_name",
        "conditionOperation" => "=",
        "targetConditionValue" => "Sam"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert "Sam.I.Am" == Map.get(result, "full_name")
      assert "Sam" == Map.get(result, "first_name")
      assert "I" == Map.get(result, "middle_initial")
      assert "Am" == Map.get(result, "last_name")
    end

    test "does nothing when condition evaluates to false" do
      payload = %{
        "first_name" => "Sam",
        "middle_initial" => "I",
        "last_name" => "Am"
      }

      parameters = %{
        "sourceFields" => "first_name, middle_initial, last_name",
        "separator" => ".",
        "targetField" => "full_name",
        "condition" => "true",
        "conditionCompareTo" => "Static Value",
        "conditionDataType" => "string",
        "sourceConditionField" => "first_name",
        "conditionOperation" => "=",
        "targetConditionValue" => "test"
      }

      {:ok, result} = Concatenation.transform(payload, parameters)

      assert nil == Map.get(result, "full_name")
      assert "Sam" == Map.get(result, "first_name")
      assert "I" == Map.get(result, "middle_initial")
      assert "Am" == Map.get(result, "last_name")
    end

    test "if any addends end with a period, return error" do

      payload = %{
        "string1" => "one",
        "string2" => "two"
      }

      parameters = %{
        "sourceFields" => "name, last_name.",
        "separator" => ".",
        "targetField" => "full_name"
      }

      {:error, reason} = Concatenation.transform(payload, parameters)

      assert reason == %{"sourceFields" => "Missing or empty child field"}
    end

    test "if target end with a period, return error" do
      payload = %{
        "string1" => "one",
        "string2" => "two"
      }

      parameters = %{
        "sourceFields" => "name, last_name.",
        "separator" => ".",
        "targetField" => "full_name."
      }

      {:error, reason} = Concatenation.transform(payload, parameters)

      assert reason == %{"sourceFields" => "Missing or empty child field", "targetField" => "Missing or empty child field"}
    end
  end

  describe "validate/1" do
    test "returns :ok if all parameters are present" do
      parameters = %{
        "sourceFields" => "other, name",
        "separator" => ".",
        "targetField" => "name"
      }

      {:ok, [source_fields, separator, target_field]} = Concatenation.validate(parameters)

      assert source_fields == parameters["sourceFields"]
      assert separator == parameters["separator"]
      assert target_field == parameters["targetField"]
    end

    data_test "when missing parameter #{parameter} return error #{message}" do
      parameters =
        %{
          "sourceFields" => "name, last_name",
          "separator" => ".",
          "targetField" => "full_name"
        }
        |> Map.delete(parameter)

      {:error, reason} = Concatenation.validate(parameters)

      assert reason == %{"#{parameter}" => "#{message}"}

      where(
        parameter: ["sourceFields", "separator", "targetField"],
        message: ["Missing or empty field", "Missing or empty field", "Missing or empty field"]
      )
    end

    test "when all parameters missing return errors for all" do
      {:error, reason} = Concatenation.validate(%{})

      assert reason == %{
               "sourceFields" => "Missing or empty field",
               "separator" => "Missing or empty field",
               "targetField" => "Missing or empty field"
             }
    end
  end
end
