defmodule Dictionary.Type.StringTest do
  use ExUnit.Case
  import Checkov

  describe "new/1" do
    test "name gets lowercased" do
      assert Dictionary.Type.String.new!(name: "name") ==
               Dictionary.Type.String.new!(name: "Name")
    end
  end

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "__type__" => "dictionary_string"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.String{
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
      "__type__" => "dictionary_string"
    }

    field = input |> Jason.encode!() |> JsonSerde.deserialize!()

    assert field == Dictionary.Type.String.new!(name: "name", description: "description")
  end

  data_test "validates strings - #{inspect(value)} --> #{inspect(result)}" do
    assert result == Dictionary.Type.Normalizer.normalize(%Dictionary.Type.String{}, value)

    where [
      [:value, :result],
      ["string", {:ok, "string"}],
      ["  string  ", {:ok, "string"}],
      [123, {:ok, "123"}],
      [nil, {:ok, ""}],
      [{:one, :two}, {:error, :invalid_string}]
    ]
  end
end
