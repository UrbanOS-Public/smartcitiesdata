defmodule Dictionary.Type.IntegerTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "__type__" => "dictionary_integer"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.Integer{
               name: "name",
               description: "description"
             })
             |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    input = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "__type__" => "dictionary_integer"
    }

    assert Dictionary.Type.Integer.new!(name: "name", description: "description") ==
             Jason.encode!(input) |> JsonSerde.deserialize!()
  end

  data_test "validates integers -- #{inspect(value)} --> #{inspect(result)}" do
    assert result == Dictionary.Type.Normalizer.normalize(%Dictionary.Type.Integer{}, value)

    where [
      [:value, :result],
      [1, {:ok, 1}],
      ["123", {:ok, 123}],
      ["one", {:error, :invalid_integer}],
      [nil, {:ok, nil}],
      ["", {:ok, nil}]
    ]
  end
end
