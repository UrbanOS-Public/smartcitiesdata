defmodule Transformers.DateTimeTest do
  use ExUnit.Case

  @tag :skip
  test "parses date and reformats" do
    params = %{
      sourceField: "date1",
      targetField: "date2",
      sourceFormat: "{YYYY}-{MM}-{D} {h24}:{m}",
      targetFormat: "{Mfull} {D}, {YYYY} {h12}:{m} {AM}"
    }

    message_payload = %{"date1" => "2022-02-28 16:53"}

    {:ok, transformed_payload} = Transformers.DateTime.transform(message_payload, params)

    {:ok, actual_transformed_field} = Map.fetch(transformed_payload, params.targetField)
    assert actual_transformed_field == "February 28, 2022 4:53 PM"
  end
end
