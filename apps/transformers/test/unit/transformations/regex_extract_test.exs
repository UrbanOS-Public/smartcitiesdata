defmodule Transformers.RegexExtractTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG

  describe "The regex extract transform" do
    test "returns an error if the specified source field does not exist" do
      params = %{
        sourceField: "source_field",
        targetField: "target_field",
        regex: "^\((\d{3})\)"
      }

      message_payload = %{"some_other_field" => "not what you were expecting"}

      {:error, reason} = Transformers.RegexExtract.transform(message_payload, params)

      assert reason == "Field source_field not found"
    end

    test "returns payload with extracted value in target field" do
      params = %{
        sourceField: "phone_number",
        targetField: "area_code",
        regex: "^\\((\\d{3})\\)"
      }

      message_payload = %{"phone_number" => "(555) 123-4567"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "area_code")
      assert actual_target_field == "555"
    end

    test "returns payload with null value in target field if no regex match" do
      params = %{
        sourceField: "phone_number",
        targetField: "area_code",
        regex: "bananas"
      }

      message_payload = %{"phone_number" => "(555) 123-4567"}

      {:ok, transformed_payload} = Transformers.RegexExtract.transform(message_payload, params)

      {:ok, actual_target_field} = Map.fetch(transformed_payload, "area_code")
      assert actual_target_field == nil
    end

    #  If target field already exists, overwrite it
    #  Error case: if regex does not compile, message is sent to dead letter queue
    #  Error case: if no matching source field, message is sent to dead letter queue
  end
end
