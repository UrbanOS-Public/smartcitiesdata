defmodule Dictionary.Type.Wkt.PointTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "__type__" => "dictionary_wkt_point"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.Wkt.Point{
               name: "name",
               description: "description"
             })
             |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    point = Dictionary.Type.Wkt.Point.new!(name: "name", description: "description")
    serialized = JsonSerde.serialize!(point)

    assert point == JsonSerde.deserialize!(serialized)
  end

  data_test "validates strings - #{inspect(value)} --> #{inspect(result)}" do
    assert result == Dictionary.Type.Normalizer.normalize(%Dictionary.Type.Wkt.Point{}, value)

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
