defmodule Dictionary.Type.FloatTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1.0,
      "name" => "name",
      "description" => "precise number",
      "__type__" => "dictionary_float"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.Float{
               name: "name",
               description: "precise number"
             })
             |> Jason.decode!()
  end

  test "can be decoded back to a struct" do
    input = %{
      "version" => 1.0,
      "name" => "name",
      "description" => "precise number",
      "__type__" => "dictionary_float"
    }

    assert %Dictionary.Type.Float{name: "name", description: "precise number"} ==
             Jason.encode!(input) |> JsonSerde.deserialize!()
  end

  data_test "validates floats -- #{inspect(value)} --> #{inspect(result)}" do
    assert result == Dictionary.Type.Normalizer.normalize(%Dictionary.Type.Float{}, value)

    where [
      [:value, :result],
      [3.14, {:ok, 3.14}],
      ["25.1", {:ok, 25.1}],
      ["quarter", {:error, :invalid_float}],
      [nil, {:ok, nil}],
      ["", {:ok, nil}]
    ]
  end
end
