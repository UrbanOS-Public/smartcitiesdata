defmodule Dictionary.Type.BooleanTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "do or do not",
      "__type__" => "dictionary_boolean"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.Boolean{
               name: "name",
               description: "do or do not"
             })
             |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    input = %{
      "version" => 1,
      "name" => "name",
      "description" => "do or do not",
      "__type__" => "dictionary_boolean"
    }

    assert Dictionary.Type.Boolean.new!(name: "name", description: "do or do not") ==
             Jason.encode!(input) |> JsonSerde.deserialize!()
  end

  data_test "validates booleans -- #{inspect(value)} --> #{inspect(result)}" do
    assert result == Dictionary.Type.Normalizer.normalize(%Dictionary.Type.Boolean{}, value)

    where [
      [:value, :result],
      [true, {:ok, true}],
      ["false", {:ok, false}],
      ["sure", {:error, :invalid_boolean}],
      [nil, {:ok, nil}],
      ["", {:ok, nil}]
    ]
  end
end
