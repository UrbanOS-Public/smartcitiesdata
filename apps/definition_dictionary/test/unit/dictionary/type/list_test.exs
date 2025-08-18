defmodule Dictionary.Type.ListTest do
  use ExUnit.Case
  import Checkov
  
  @moduletag timeout: 5000

  test "can be encoded to json" do
    expected = %{
      "version" => 1,
      "name" => "list",
      "description" => "description",
      "__type__" => "dictionary_list",
      "item_type" => %{
        "version" => 1,
        "name" => "in_list",
        "description" => "",
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
    }

    list =
      Dictionary.Type.List.new!([
        name: "list",
        description: "description",
        item_type:
          Dictionary.Type.Map.new!([
            name: "in_list",
            dictionary:
              Dictionary.from_list([
                Dictionary.Type.String.new!([name: "name"], IdGenerator.Impl),
                Dictionary.Type.Integer.new!([name: "age"], IdGenerator.Impl)
              ])
          ], IdGenerator.Impl)
      ], IdGenerator.Impl)

    assert expected == JsonSerde.serialize!(list) |> Jason.decode!()
  end

  test "can be decoded back into struct" do
    list =
      Dictionary.Type.List.new!([
        name: "name",
        description: "description",
        item_type:
          Dictionary.Type.Map.new!([
            name: "in_list",
            dictionary: [
              Dictionary.Type.String.new!([name: "name"], IdGenerator.Impl),
              Dictionary.Type.Integer.new!([name: "age"], IdGenerator.Impl)
            ]
          ], IdGenerator.Impl)
      ], IdGenerator.Impl)

    serialized = JsonSerde.serialize!(list)

    assert list == JsonSerde.deserialize!(serialized)
  end

  data_test "normalizes data in maps according to field rules" do
    field = %Dictionary.Type.List{
      name: "friends",
      item_type:
        Dictionary.Type.Map.new!([
          name: "in_list",
          dictionary:
            Dictionary.from_list([
              Dictionary.Type.String.new!([name: "name"], IdGenerator.Impl),
              Dictionary.Type.Integer.new!([name: "age"], IdGenerator.Impl)
            ])
        ], IdGenerator.Impl)
    }

    value = [
      %{
        "name" => name,
        "age" => age
      }
    ]

    assert result == Dictionary.Type.Normalizer.normalize(field, value)

    where [
      [:name, :age, :result],
      ["holly", 27, {:ok, [%{"name" => "holly", "age" => 27}]}],
      [
        {:one},
        "abc",
        {:error, {:invalid_list, %{"name" => :invalid_string, "age" => :invalid_integer}}}
      ]
    ]
  end

  test "normalizes data in simple type" do
    field = %Dictionary.Type.List{
      item_type: Dictionary.Type.String.new!([name: "in_list"], IdGenerator.Impl)
    }

    value = [
      "one",
      "  two  "
    ]

    assert {:ok, ["one", "two"]} == Dictionary.Type.Normalizer.normalize(field, value)
  end

  test "handles nil" do
    field = %Dictionary.Type.List{
      item_type: Dictionary.Type.String.new!([name: "in_list"], IdGenerator.Impl)
    }

    assert {:ok, nil} == Dictionary.Type.Normalizer.normalize(field, nil)
  end

  describe "access" do
    setup do
      list =
        Dictionary.Type.List.new!([
          name: "name",
          item_type:
            Dictionary.Type.Map.new!([
              name: "in_list",
              dictionary:
                Dictionary.from_list([
                  Dictionary.Type.String.new!([name: "name"], IdGenerator.Impl),
                  Dictionary.Type.Integer.new!([name: "age"], IdGenerator.Impl),
                  Dictionary.Type.List.new!([
                    name: "friends",
                    item_type:
                      Dictionary.Type.Map.new!([
                        name: "in_list",
                        dictionary:
                          Dictionary.from_list([
                            Dictionary.Type.String.new!([name: "friend_name"], IdGenerator.Impl),
                            Dictionary.Type.Integer.new!([name: "friend_age"], IdGenerator.Impl)
                          ])
                      ], IdGenerator.Impl)
                  ], IdGenerator.Impl)
                ])
            ], IdGenerator.Impl)
        ], IdGenerator.Impl)

      [list: list]
    end

    test "fetch", %{list: list} do
      assert Dictionary.Type.String.new!([name: "friend_name"], IdGenerator.Impl) ==
               get_in(list, ["friends", "friend_name"])
    end

    test "get_and_update", %{list: list} do
      {get, update} =
        get_and_update_in(list, ["friends", "friend_age"], fn x ->
          {x, %{x | name: "friend_years_lived"}}
        end)

      assert Dictionary.Type.Integer.new!([name: "friend_age"], IdGenerator.Impl) == get

      assert Dictionary.Type.Integer.new!([name: "friend_years_lived"], IdGenerator.Impl) ==
               get_in(update, ["friends", "friend_years_lived"])
    end

    test "pop", %{list: list} do
      {_, update} = pop_in(list, ["friends", "friend_age"])
      assert nil == get_in(update, ["friends", "friend_age"])
    end
  end
end
