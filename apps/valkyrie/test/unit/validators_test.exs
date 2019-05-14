defmodule Valkyrie.ValidatorsTest do
  use ExUnit.Case
  doctest Valkyrie.Validators
  alias Valkyrie.Validators
  alias SmartCity.TestDataGenerator, as: TDG

  describe "get_invalid_fields/2" do
    test "returns an empty list when payload structure matches schema" do
      cool_schema = [
        %{name: "id", type: "integer"},
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      [msg] = TDG.create_data([dataset_id: "cool_data", payload: %{id: 123, name: "Benji", age: 31}], 1)

      assert Validators.get_invalid_fields(msg.payload, cool_schema) == []
    end

    test "returns an empty list when payload structure matches schema with different cased keys" do
      schema = [
        %{name: "fooBar", type: "string"},
        %{name: "abcXyz", type: "integer"}
      ]

      [msg] = TDG.create_data(%{dataset_id: "case", payload: %{fooBar: "baz", abcXyz: 42}}, 1)

      assert Validators.get_invalid_fields(msg.payload, schema) == []
    end

    test "returns an empty list when nested payload structure matches schema" do
      cooler_schema = [
        %{name: "name", type: "string"},
        %{
          name: "info",
          type: "map",
          subSchema: [
            %{name: "age", type: "integer"},
            %{name: "hometown", type: "string"},
            %{name: "hobbies", type: "list", itemType: "string"}
          ]
        }
      ]

      [msg] =
        TDG.create_data(
          [
            dataset_id: "cooler_data",
            payload: %{
              name: "Bobby",
              info: %{age: 34, hometown: "Arlen", hobbies: ["comedy", "eating"]}
            }
          ],
          1
        )

      assert Validators.get_invalid_fields(msg.payload, cooler_schema) == []
    end

    test "returns an empty list when a payload containing an array of nested structure matches schema" do
      coolest_schema = [
        %{name: "name", type: "string"},
        %{
          name: "bio",
          type: "list",
          itemType: "map",
          subSchema: [
            [%{name: "hometown", type: "string"}, %{name: "pet", type: "string"}],
            [
              %{name: "birth_month", type: "string"},
              %{name: "books", type: "list", itemType: "string"}
            ]
          ]
        }
      ]

      [msg] =
        TDG.create_data(
          [
            dataset_id: "coolest_data",
            payload: %{
              name: "Hank",
              bio: [
                %{hometown: "Arlen", pet: "Ladybird"},
                %{birth_month: "July", books: ["Propane 101", "Football from the Alley"]}
              ]
            }
          ],
          1
        )

      assert Validators.get_invalid_fields(msg.payload, coolest_schema) == []
    end

    test "returns a list of invalid fields when a payload doesn't match the schema" do
      sad_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"},
        %{name: "hobbies", type: "list", itemType: "string"}
      ]

      [msg] = TDG.create_data([dataset_id: "sad_data", payload: %{name: "Peggy", age: 37}], 1)

      assert Validators.get_invalid_fields(msg.payload, sad_schema) == ["hobbies"]
    end

    test "returns a list of invalid fields when a payload value matches the field name" do
      header_schema = [
        %{name: "col1", type: "string"},
        %{name: "col2", type: "string"}
      ]

      [msg] = TDG.create_data(%{dataset_id: "foo", payload: %{col1: "col1", col2: "col2"}}, 1)

      assert Validators.get_invalid_fields(msg.payload, header_schema) == ["col1", "col2"]
    end

    test "returns a list of invalid fields when a payload containing an array of nested structure doesn't match schema" do
      coolest_schema = [
        %{name: "name", type: "string"},
        %{
          name: "bio",
          type: "list",
          itemType: "map",
          subSchema: [
            [%{name: "hometown", type: "string"}, %{name: "pet", type: "string"}],
            [
              %{name: "birth_month", type: "string"},
              %{name: "books", type: "list", itemType: "string"}
            ]
          ]
        }
      ]

      [msg] =
        TDG.create_data(
          [
            dataset_id: "coolest_data",
            payload: %{
              bio: [
                %{hometown: "Arlen"},
                %{birth_month: "July"}
              ]
            }
          ],
          1
        )

      assert Validators.get_invalid_fields(msg.payload, coolest_schema) == ["name", "pet", "books"]
    end
  end
end
