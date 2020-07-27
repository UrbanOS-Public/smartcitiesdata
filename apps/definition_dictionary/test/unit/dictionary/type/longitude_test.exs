defmodule Dictionary.Type.LongitudeTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "__type__" => "dictionary_longitude"
    }

    assert expected ==
             JsonSerde.serialize!(%Dictionary.Type.Longitude{
               name: "name",
               description: "description"
             })
             |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    longitude = Dictionary.Type.Longitude.new!(name: "name", description: "description")
    serialized = JsonSerde.serialize!(longitude)

    assert longitude == JsonSerde.deserialize!(serialized)
  end

  data_test "validates longitudes - #{inspect(value)} --> #{inspect(result)}" do
    assert result == Dictionary.Type.Normalizer.normalize(%Dictionary.Type.Longitude{}, value)

    where [
      [:value, :result],
      ["180", {:ok, 180.0}],
      ["180.0", {:ok, 180.0}],
      [180, {:ok, 180.0}],
      [180.0, {:ok, 180.0}],
      ["-180.0", {:ok, -180.0}],
      ["-180", {:ok, -180.0}],
      [-180, {:ok, -180.0}],
      [-180.0, {:ok, -180.0}],
      [181, {:error, :invalid_longitude}],
      [180.000001, {:error, :invalid_longitude}],
      [179.9999999, {:ok, 179.9999999}],
      [-181, {:error, :invalid_longitude}],
      [-181.000001, {:error, :invalid_longitude}],
      [-179.9999999, {:ok, -179.9999999}],
      ["seventy-six", {:error, :invalid_longitude}],
      [nil, {:ok, nil}],
      ["", {:ok, nil}]
    ]
  end
end
