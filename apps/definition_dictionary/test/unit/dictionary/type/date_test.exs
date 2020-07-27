defmodule Dictionary.Type.DateTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "format" => "%Y-%0m-%0d",
      "__type__" => "dictionary_date"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.Date{
               name: "name",
               description: "description",
               format: "%Y-%0m-%0d"
             })
             |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    input = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "format" => "%Y-%0m-%0d",
      "__type__" => "dictionary_date"
    }

    assert %Dictionary.Type.Date{
             name: "name",
             description: "description",
             format: "%Y-%0m-%0d"
           } == Jason.encode!(input) |> JsonSerde.deserialize!()
  end

  data_test "validates dates - #{inspect(value)} --> #{inspect(result)}" do
    field = Dictionary.Type.Date.new!(name: "fake", format: format)
    assert result == Dictionary.Type.Normalizer.normalize(field, value)

    where [
      [:format, :value, :result],
      ["%Y-%0m-%0d", "2020-01-01", {:ok, "2020-01-01"}],
      ["%0m-%0d-%Y", "05-10-1989", {:ok, "1989-05-10"}],
      ["%Y", "1999-05-01", {:error, "Expected end of input at line 1, column 4"}],
      ["%Y", "", {:ok, ""}],
      ["%Y", nil, {:ok, ""}]
    ]
  end
end
