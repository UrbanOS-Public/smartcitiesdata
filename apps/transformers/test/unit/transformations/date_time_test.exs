defmodule Transformers.DateTimeTest do
  use ExUnit.Case
  use Checkov

  test "parses date and reformats onto a different field" do
    params = %{
      "sourceField" => "date1",
      "targetField" => "date2",
      "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
      "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    message_payload = %{"date1" => "2022-02-28 16:53"}

    {:ok, transformed_payload} = Transformers.DateTime.transform(message_payload, params)

    {:ok, actual_transformed_field} = Map.fetch(transformed_payload, params["targetField"])
    assert actual_transformed_field == "February 28, 2022 4:53 PM"
  end

  test "when source and target are the same field, source is overwritten" do
    params = %{
      "sourceField" => "date1",
      "targetField" => "date1",
      "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
      "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    message_payload = %{"date1" => "2022-02-28 16:53"}

    {:ok, transformed_payload} = Transformers.DateTime.transform(message_payload, params)

    {:ok, actual_transformed_field} = Map.fetch(transformed_payload, params["targetField"])
    assert actual_transformed_field == "February 28, 2022 4:53 PM"
  end

  test "non source/target payload values are unaltered" do
    params = %{
      "sourceField" => "date1",
      "targetField" => "date1",
      "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
      "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    message_payload = %{"date1" => "2022-02-28 16:53", "other_field" => "other_data"}

    {:ok, transformed_payload} = Transformers.DateTime.transform(message_payload, params)

    assert transformed_payload == %{
             "date1" => "February 28, 2022 4:53 PM",
             "other_field" => "other_data"
           }
  end

  describe "error handling" do
    data_test "returns error when #{parameter} not there" do
      params =
        %{
          "sourceField" => "date1",
          "targetField" => "date2",
          "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
          "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
        }
        |> Map.delete(parameter)

      {:error, reason} = Transformers.DateTime.transform(%{}, params)

      assert reason == "Missing transformation parameter: #{parameter}"

      where(parameter: ["sourceField", "sourceFormat", "targetField", "targetFormat"])
    end

    test "returns error when sourceField is missing from payload" do
      sourceField = "missing"

      params = %{
        "sourceField" => sourceField,
        "targetField" => "date2",
        "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
        "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      }

      message_payload = %{"date1" => "2022-02-28 16:53"}

      {:error, reason} = Transformers.DateTime.transform(message_payload, params)

      assert reason == "Missing field in payload: missing"
    end

    test "returns error when sourceFormat doesn't match sourceField value" do
      sourceField = "date1"
      sourceFormat = "{Mfull}"

      params = %{
        "sourceField" => sourceField,
        "targetField" => "date2",
        "sourceFormat" => sourceFormat,
        "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      }

      message_payload = %{"date1" => "2022-02-28 16:53"}

      {:error, reason} = Transformers.DateTime.transform(message_payload, params)

      assert reason ==
               "Unable to parse datetime from \"#{sourceField}\" in format \"#{sourceFormat}\": Expected `full month name` at line 1, column 1."
    end

    test "returns error when target formatting string is bad" do
      params = %{
        "sourceField" => "date1",
        "targetField" => "date2",
        "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
        "targetFormat" => "{nonsense}"
      }

      message_payload = %{"date1" => "2022-02-28 16:53"}

      {:error, reason} = Transformers.DateTime.transform(message_payload, params)

      assert reason ==
               "Unable to format datetime in format \"#{params["targetFormat"]}\": Expected at least one parser to succeed at line 1, column 0."
    end
  end
end
