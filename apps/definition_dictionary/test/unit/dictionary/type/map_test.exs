defmodule Dictionary.Type.MapTest do
  use ExUnit.Case
  import Checkov

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "name",
      "description" => "description",
      "__type__" => "dictionary_map",
      "dictionary" => %{
        "__type__" => "dictionary",
        "fields" => [
          %{
            "version" => 1,
            "name" => "name",
            "description" => "",
            "__type__" => "dictionary_string"
          },
          %{
            "version" => 1,
            "name" => "age",
            "description" => "",
            "__type__" => "dictionary_integer"
          }
        ]
      }
    }

    map =
      Dictionary.Type.Map.new!(
        name: "name",
        description: "description",
        dictionary:
          Dictionary.from_list([
            %Dictionary.Type.String{name: "name"},
            %Dictionary.Type.Integer{name: "age"}
          ])
      )

    assert expected == JsonSerde.serialize!(map) |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    map =
      Dictionary.Type.Map.new!(
        name: "name",
        description: "description",
        dictionary:
          Dictionary.from_list([
            Dictionary.Type.String.new!(name: "name"),
            Dictionary.Type.Integer.new!(name: "age")
          ])
      )

    serialized = JsonSerde.serialize!(map)

    assert map == JsonSerde.deserialize!(serialized)
  end

  data_test "normalizes all fields inside map" do
    value = %{
      "name" => name,
      "age" => age
    }

    field =
      Dictionary.Type.Map.new!(
        name: "spouse",
        dictionary: [
          %Dictionary.Type.String{name: "name"},
          %Dictionary.Type.Integer{name: "age"}
        ]
      )

    assert result == Dictionary.Type.Normalizer.normalize(field, value)

    where [
      [:name, :age, :result],
      ["george", 21, {:ok, %{"name" => "george", "age" => 21}}],
      ["fred", "abc", {:error, %{"age" => :invalid_integer}}]
    ]
  end

  test "handles nil" do
    field =
      Dictionary.Type.Map.new!(
        name: "spouse",
        dictionary: [
          %Dictionary.Type.String{name: "name"},
          %Dictionary.Type.Integer{name: "age"}
        ]
      )

    assert {:ok, nil} == Dictionary.Type.Normalizer.normalize(field, nil)
  end
end
