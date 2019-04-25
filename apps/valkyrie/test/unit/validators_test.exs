defmodule Valkyrie.ValidatorsTest do
  use ExUnit.Case

  alias Valkyrie.Validators
  alias SmartCity.TestDataGenerator, as: TDG

  describe "schema_satisfied?/2" do
    test "returns true when payload structure matches schema" do
      cool_schema = [
        %{name: "id", type: "integer"},
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      [msg] = TDG.create_data([dataset_id: "cool_data", payload: %{id: 123, name: "Benji", age: 31}], 1)

      assert Validators.schema_satisfied?(msg.payload, cool_schema) == true
    end

    test "returns true when payload structure matches schema with different cased keys" do
      schema = [
        %{name: "fooBar", type: "string"},
        %{name: "abcXyz", type: "integer"}
      ]

      [msg] = TDG.create_data(%{dataset_id: "case", payload: %{fooBar: "baz", abcXyz: 42}}, 1)

      assert Validators.schema_satisfied?(msg.payload, schema) == true
    end

    test "returns true when nested payload structure matches schema" do
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

      assert Validators.schema_satisfied?(msg.payload, cooler_schema) == true
    end

    test "returns true when a payload containing an array of nested structure matches schema" do
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

      assert Validators.schema_satisfied?(msg.payload, coolest_schema) == true
    end

    test "returns false when a payload doesn't match the schema" do
      sad_schema = [
        %{name: "name", type: "string"},
        %{name: "age", type: "integer"},
        %{name: "hobbies", type: "list", itemType: "string"}
      ]

      [msg] = TDG.create_data([dataset_id: "sad_data", payload: %{name: "Peggy", age: 37}], 1)

      assert Validators.schema_satisfied?(msg.payload, sad_schema) == false
    end

    test "returns false when a payload value matches the field name" do
      header_schema = [
        %{name: "col1", type: "string"},
        %{name: "col2", type: "string"}
      ]

      [msg] = TDG.create_data(%{dataset_id: "foo", payload: %{col1: "col1", col2: "col2"}}, 1)

      assert Validators.schema_satisfied?(msg.payload, header_schema) == false
    end
  end
end
