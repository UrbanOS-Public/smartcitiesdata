defmodule Transformers.DateTimeTest do
  use ExUnit.Case
  use Checkov

  alias Transformers.DateTime

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

      assert reason == %{"#{parameter}" => "Missing or empty field"}

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

    test "returns error when date in payload does not match expected source format" do
      params = %{
        "sourceField" => "date1",
        "targetField" => "date2",
        "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
        "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      }

      message_payload = %{"date1" => "02-28 16:53"}

      {:error, reason} = Transformers.DateTime.transform(message_payload, params)

      assert reason ==
               "Unable to parse datetime from \"date1\" in format \"{YYYY}-{0M}-{D} {h24}:{m}\": Expected `2 digit month` at line 1, column 4."
    end
  end

  describe "validate/1" do
    test "returns :ok if all parameters are present and valid" do
      parameters = %{
        "sourceField" => "date1",
        "targetField" => "date2",
        "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
        "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
      }

      {:ok, [source_field, source_format, target_field, target_format]} =
        DateTime.validate_parameters(parameters)

      assert source_field == parameters["sourceField"]
      assert source_format == parameters["sourceFormat"]
      assert target_field == parameters["targetField"]
      assert target_format == parameters["targetFormat"]
    end

    data_test "when missing parameter #{parameter} return error" do
      parameters =
        %{
          "sourceField" => "date1",
          "targetField" => "date2",
          "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
          "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
        }
        |> Map.delete(parameter)

      {:error, reason} = DateTime.validate_parameters(parameters)

      assert reason == %{"#{parameter}" => "Missing or empty field"}

      where(parameter: ["sourceField", "sourceFormat", "targetField", "targetFormat"])
    end

    data_test "returns error when #{format} is invalid Timex DateTime format" do
      params =
        %{
          "sourceField" => "date1",
          "targetField" => "date2",
          "sourceFormat" => "{YYYY}-{0M}-{D} {h24}:{m}",
          "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
        }
        |> Map.delete(format)
        |> Map.put(format, "{invalid}")

      {:error, reason} = Transformers.DateTime.validate_parameters(params)

      assert reason == %{
               "#{format}" =>
                 "DateTime format \"{invalid}\" is invalid: Expected at least one parser to succeed at line 1, column 0."
             }

      where(format: ["sourceFormat", "targetFormat"])
    end

    test "when one field has multiple errors the missing field error wins" do
      parameters =
        %{
          "sourceField" => "date1",
          "targetField" => "date2",
          "sourceFormat" => "",
          "targetFormat" => "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
        }
        |> Map.delete("sourceFormat")

      {:error, reason} = DateTime.validate_parameters(parameters)

      assert reason == %{"sourceFormat" => "Missing or empty field"}
    end
  end
end
