defmodule DictionaryTest do
  use ExUnit.Case
  import Checkov

  describe "dictionary data structure" do
    setup do
      dictionary =
        Dictionary.from_list([
          Dictionary.Type.String.new!(name: "name"),
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.Date.new!(name: "birthdate", format: "%Y-%m-%d")
        ])

      [dictionary: dictionary]
    end

    test "get_field returns field by name", %{dictionary: dictionary} do
      assert Dictionary.Type.String.new!(name: "name") == Dictionary.get_field(dictionary, "name")
    end

    data_test "get_by_type returns all fields with that type" do
      dictionary =
        Dictionary.from_list([
          Dictionary.Type.String.new!(name: "name"),
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.Date.new!(name: "birthdate", format: "%Y-%m-%d"),
          Dictionary.Type.String.new!(name: "nickname"),
          Dictionary.Type.Map.new!(
            name: "spouse",
            dictionary: [
              Dictionary.Type.String.new!(name: "name"),
              Dictionary.Type.Wkt.Point.new!(name: "location")
            ]
          ),
          Dictionary.Type.List.new!(
            name: "friends",
            item_type:
              Dictionary.Type.Map.new!(
                name: "in_list",
                dictionary: [
                  Dictionary.Type.String.new!(name: "name"),
                  Dictionary.Type.Map.new!(
                    name: "work",
                    dictionary: [
                      Dictionary.Type.Wkt.Point.new!(name: "location")
                    ]
                  )
                ]
              )
          ),
          Dictionary.Type.List.new!(
            name: "colors",
            item_type: Dictionary.Type.String.new!(name: "in_list")
          )
        ])

      result_from_list = Dictionary.get_by_type(dictionary, type)
      result_from_struct = Dictionary.from_list(dictionary) |> Dictionary.get_by_type(type)

      assert MapSet.new(result_from_list) == MapSet.new(expected)
      assert MapSet.new(result_from_struct) == MapSet.new(expected)

      where [
        [:type, :expected],
        [
          Dictionary.Type.String,
          [["name"], ["nickname"], ["spouse", "name"], ["friends", "name"]]
        ],
        [Dictionary.Type.Integer, [["age"]]],
        [Dictionary.Type.Wkt.Point, [["spouse", "location"], ["friends", "work", "location"]]],
        [Dictionary.Type.Map, [["friends", "work"], ["spouse"]]],
        [Dictionary.Type.List, [["colors"], ["friends"]]]
      ]
    end

    test "update_field update field in dictionary", %{dictionary: dictionary} do
      new_dictionary =
        Dictionary.update_field(
          dictionary,
          "name",
          Dictionary.Type.String.new!(name: "full_name")
        )

      assert Dictionary.Type.String.new!(name: "full_name") ==
               Dictionary.get_field(new_dictionary, "full_name")

      assert nil == Dictionary.get_field(new_dictionary, "name")
    end

    test "update_field can also update field via function", %{dictionary: dictionary} do
      new_dictionary =
        Dictionary.update_field(dictionary, "name", fn field ->
          %{field | name: "full_name"}
        end)

      assert Dictionary.Type.String.new!(name: "full_name") ==
               Dictionary.get_field(new_dictionary, "full_name")

      assert nil == Dictionary.get_field(new_dictionary, "name")
    end

    test "delete_field will remove the field from thje dictionary and maintain the indexes", %{
      dictionary: dictionary
    } do
      new_dictionary = Dictionary.delete_field(dictionary, "age")

      assert Enum.to_list(new_dictionary) == [
               Dictionary.Type.String.new!(name: "name"),
               Dictionary.Type.Date.new!(name: "birthdate", format: "%Y-%m-%d")
             ]
    end
  end

  describe "normalize/2" do
    test "normalized a correct payload" do
      dictionary = [
        %Dictionary.Type.String{name: "name"},
        %Dictionary.Type.Integer{name: "age"}
      ]

      payload = %{
        "name" => "brian",
        "age" => 21
      }

      assert {:ok, payload} == Dictionary.normalize(dictionary, payload)
    end

    test "payload is put through type coercion" do
      dictionary = [
        %Dictionary.Type.String{name: "name"},
        %Dictionary.Type.Integer{name: "age"}
      ]

      payload = %{
        "name" => :brian,
        "age" => "21"
      }

      expected = %{
        "name" => "brian",
        "age" => 21
      }

      assert {:ok, expected} == Dictionary.normalize(dictionary, payload)
    end

    test "reports all errors found during normalization" do
      dictionary =
        [
          Dictionary.Type.String.new!(name: "name"),
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.Map.new!(
            name: "spouse",
            dictionary: [
              %Dictionary.Type.String{name: "name"},
              %Dictionary.Type.Integer{name: "age"}
            ]
          )
        ]
        |> Dictionary.from_list()

      payload = %{
        "name" => {:one, :two},
        "age" => "one",
        "spouse" => %{
          "name" => "shelly",
          "age" => "twenty-one"
        }
      }

      expected = %{
        "name" => :invalid_string,
        "age" => :invalid_integer,
        "spouse" => %{"age" => :invalid_integer}
      }

      assert {:error, expected} == Dictionary.normalize(dictionary, payload)
    end
  end

  describe "Access" do
    setup do
      dictionary =
        Dictionary.from_list([
          Dictionary.Type.String.new!(name: "name"),
          Dictionary.Type.Integer.new!(name: "age"),
          Dictionary.Type.Date.new!(name: "birthdate", format: "%Y-%m-%d"),
          Dictionary.Type.Map.new!(
            name: "spouse",
            dictionary: [
              Dictionary.Type.String.new!(name: "name"),
              Dictionary.Type.Integer.new!(name: "age"),
              Dictionary.Type.String.new!(name: "nickname")
            ]
          )
        ])

      [dictionary: dictionary]
    end

    test "can access field of dictionary", %{dictionary: dictionary} do
      assert dictionary["name"] == Dictionary.get_field(dictionary, "name")
    end

    test "it handle fields that don't exist", %{dictionary: dictionary} do
      assert dictionary["nickname"] == nil
    end

    test "can add field to the dictionary", %{dictionary: dictionary} do
      nickname = Dictionary.Type.String.new!(name: "nickname")
      result = Dictionary.update_field(dictionary, "nickname", nickname)

      expected = Dictionary.from_list(Enum.to_list(dictionary) ++ [nickname])

      assert expected == result
    end

    test "can update the field in dictionary", %{dictionary: dictionary} do
      result =
        update_in(dictionary, ["birthdate"], fn field ->
          %{field | name: "other_date"}
        end)

      assert Dictionary.get_field(result, "other_date") ==
               Dictionary.Type.Date.new!(name: "other_date", format: "%Y-%m-%d")
    end

    test "can pop field in dictionary", %{dictionary: dictionary} do
      {_, result} = pop_in(dictionary, ["birthdate"])

      assert nil == Dictionary.get_field(result, "birthdate")
    end

    test "can pop using get_and_update_in", %{dictionary: dictionary} do
      {field, result} = get_and_update_in(dictionary, ["birthdate"], fn _ -> :pop end)

      assert field == Dictionary.Type.Date.new!(name: "birthdate", format: "%Y-%m-%d")

      assert nil == Dictionary.get_field(result, "birthdate")
    end
  end

  test "dictionary can be serialized/deserialized" do
    dictionary =
      Dictionary.from_list([
        Dictionary.Type.String.new!(name: "name"),
        Dictionary.Type.Integer.new!(name: "age")
      ])

    expected = %{
      "__type__" => "dictionary",
      "fields" => [
        %{
          "__type__" => "dictionary_string",
          "name" => "name",
          "description" => "",
          "version" => 1
        },
        %{
          "__type__" => "dictionary_integer",
          "name" => "age",
          "description" => "",
          "version" => 1
        }
      ]
    }

    serialized = JsonSerde.serialize!(dictionary)

    assert expected == Jason.decode!(serialized)

    deserialized = JsonSerde.deserialize!(serialized)

    assert dictionary == deserialized
  end
end
