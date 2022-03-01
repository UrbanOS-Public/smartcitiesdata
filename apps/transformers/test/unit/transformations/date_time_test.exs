defmodule Transformers.DateTimeTest do
  use ExUnit.Case

  test "parses date and reformats onto a different field" do
    params = %{
      sourceField: "date1",
      targetField: "date2",
      sourceFormat: "{YYYY}-{0M}-{D} {h24}:{m}",
      targetFormat: "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    message_payload = %{"date1" => "2022-02-28 16:53"}

    {:ok, transformed_payload} = Transformers.DateTime.transform(message_payload, params)

    {:ok, actual_transformed_field} = Map.fetch(transformed_payload, params.targetField)
    assert actual_transformed_field == "February 28, 2022 4:53 PM"
  end

  test "returns error when sourceFormat doesn't match sourceField value" do
    sourceField = "date1"
    sourceFormat = "{Mfull}"

    params = %{
      sourceField: sourceField,
      targetField: "date2",
      sourceFormat: sourceFormat,
      targetFormat: "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    message_payload = %{"date1" => "2022-02-28 16:53"}

    {:error, reason} = Transformers.DateTime.transform(message_payload, params)

    assert reason ==
             "Unable to parse datetime from \"#{sourceField}\" in format \"#{sourceFormat}\": Expected `full month name` at line 1, column 1."
  end

  # "parses date and overwrites an existing payload field"
end
