defmodule Transformers.RegexExtractTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.RegexExtract

  describe "The regex extract transform" do
    test "returns payload with extracted value in target field" do
      params = %{
        "sourceField" => "phone_number",
        "targetField" => "area_code",
        "regex" => "^\\((\\d{3})\\)"
      }

      message_payload = %{"phone_number" => "(555) 123-4567"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "area_code")
      assert actual_target_field == "555"
    end

    test "returns payload with null value in target field if no regex match" do
      params = %{
        "sourceField" => "phone_number",
        "targetField" => "area_code",
        "regex" => "bananas"
      }

      message_payload = %{"phone_number" => "(555) 123-4567"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "area_code")
      assert actual_target_field == nil
    end

    test "returns payload with overwritten target field" do
      params = %{
        "sourceField" => "full_name",
        "targetField" => "first_name",
        "regex" => "^(\\w+)"
      }

      message_payload = %{"full_name" => "Jane Austen", "first_name" => "n/a"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "first_name")
      assert actual_target_field == "Jane"
    end

    test "returns an error if the specified source field does not exist" do
      params = %{
        "sourceField" => "source_field",
        "targetField" => "target_field",
        "regex" => "^\((\d{3})\)"
      }

      message_payload = %{"some_other_field" => "not what you were expecting"}

      {:error, reason} = Transformers.RegexExtract.transform(message_payload, params)

      assert reason == "Missing field in payload: source_field"
    end

    test "returns an error if the regex does not compile" do
      params = %{
        "sourceField" => "source_field",
        "targetField" => "target_field",
        "regex" => "^\((\d{3})"
      }

      message_payload = %{"source_field" => "field"}

      {:error, reason} = Transformers.RegexExtract.transform(message_payload, params)

      assert reason == %{"regex" => "Invalid regular expression: missing ) at index 8"}
    end

    test "if source and target field are the same overwrite original value" do
      params = %{
        "sourceField" => "name",
        "targetField" => "name",
        "regex" => "^(\\w+)"
      }

      message_payload = %{"name" => "Emily Wilkenson"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      assert transformed_payload == %{"name" => "Emily"}
    end

    test "performs transformation as normal when condition evaluates to true" do
      params = %{
        "sourceField" => "phone_number",
        "targetField" => "area_code",
        "regex" => "^\\((\\d{3})\\)",
        "condition" => %{
          "conditionDataType" => "string",
          "sourceConditionField" => "phone_number",
          "conditionOperation" => "=",
          "targetConditionValue" => "(555) 123-4567"
        }
      }

      message_payload = %{"phone_number" => "(555) 123-4567"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "area_code")
      assert actual_target_field == "555"
    end

    test "does nothing when condition evaluates to false" do
      params = %{
        "sourceField" => "phone_number",
        "targetField" => "area_code",
        "regex" => "^\\((\\d{3})\\)",
        "condition" => %{
          "conditionDataType" => "string",
          "sourceConditionField" => "phone_number",
          "conditionOperation" => "=",
          "targetConditionValue" => "value"
        }
      }

      message_payload = %{"phone_number" => "(555) 123-4567"}

      result = Transformers.RegexExtract.transform(message_payload, params)

      assert result == {:ok, %{"phone_number" => "(555) 123-4567"}}
    end
  end

  describe "validate/1" do
    test "returns :ok if all parameters are present and valid" do
      parameters = %{
        "sourceField" => "phone_number",
        "targetField" => "area_code",
        "regex" => "^\\((\\d{3})\\)"
      }

      {:ok, [source_field, target_field, regex]} = RegexExtract.validate(parameters)

      assert source_field == parameters["sourceField"]
      assert target_field == parameters["targetField"]
      assert regex == Regex.compile!(parameters["regex"])
    end

    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "sourceField" => "phone_number",
          "targetField" => "area_code",
          "regex" => "^\\((\\d{3})\\)"
        }
        |> Map.delete(parameter)

      {:error, reason} = RegexExtract.validate(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["sourceField", "targetField", "regex"])
    end

    test "returns error when regex is invalid" do
      params = %{
        "sourceField" => "source_field",
        "targetField" => "target_field",
        "regex" => "^\((\d{3})"
      }

      {:error, reason} = RegexExtract.validate(params)

      assert reason == %{"regex" => "Invalid regular expression: missing ) at index 8"}
    end
  end
end
