defmodule Forklift.Messages.SchemaFillerTest do
  use ExUnit.Case
  doctest SmartCity.Helpers
  alias Forklift.Messages.SchemaFiller

  describe "single level" do
    setup do
      basic_schema = [
        %{name: "id", type: "string"},
        %{
          name: "parent",
          type: "map",
          subSchema: [%{name: "childA", type: "string"}, %{name: "childB", type: "string"}]
        }
      ]

      list_schema = [
        %{name: "id", type: "string"},
        %{
          name: "parent",
          type: "list",
          itemType: "string"
        }
      ]

      [
        basic_schema: basic_schema,
        list_schema: list_schema
      ]
    end

    test "nil map", %{basic_schema: schema} do
      payload = %{id: "id", parent: nil}

      expected = %{
        id: "id",
        parent: nil
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty map", %{basic_schema: schema} do
      payload = %{id: "id", parent: %{}}

      expected = %{
        id: "id",
        parent: nil
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "partial map", %{basic_schema: schema} do
      payload = %{id: "id", parent: %{childA: "childA"}}

      expected = %{
        id: "id",
        parent: %{childA: "childA", childB: nil}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty list", %{list_schema: schema} do
      payload = %{id: "id", parent: []}

      expected = %{
        id: "id",
        parent: []
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with string item", %{list_schema: schema} do
      payload = %{id: "id", parent: ["thing"]}

      expected = %{
        id: "id",
        parent: ["thing"]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end
  end

  describe "two levels" do
    setup do
      two_level_list_schema = [
        %{name: "id", type: "string"},
        %{
          name: "parent",
          type: "list",
          itemType: "map",
          subSchema: [%{name: "childA", type: "string"}, %{name: "childB", type: "string"}]
        }
      ]

      nested_maps_schema = [
        %{name: "id", type: "string"},
        %{
          name: "grandParent",
          type: "map",
          subSchema: [
            %{
              name: "parent",
              type: "map",
              subSchema: [%{name: "childA", type: "string"}, %{name: "childB", type: "string"}]
            }
          ]
        }
      ]

      [
        two_level_list_schema: two_level_list_schema,
        nested_maps_schema: nested_maps_schema
      ]
    end

    test "list with empty map", %{two_level_list_schema: schema} do
      payload = %{id: "id", parent: [%{}]}

      expected = %{
        id: "id",
        parent: []
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with nil", %{two_level_list_schema: schema} do
      payload = %{id: "id", parent: [nil]}

      expected = %{
        id: "id",
        parent: []
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with one good value and two ignored values", %{two_level_list_schema: schema} do
      payload = %{id: "id", parent: [%{}, %{childA: "child"}, nil]}

      expected = %{
        id: "id",
        parent: [%{childA: "child", childB: nil}]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with partial map", %{two_level_list_schema: schema} do
      payload = %{id: "id", parent: [%{childA: "childA"}]}

      expected = %{
        id: "id",
        parent: [%{childA: "childA", childB: nil}]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with 2 partial maps", %{two_level_list_schema: schema} do
      payload = %{id: "id", parent: [%{childA: "childA"}, %{childB: "childB"}]}

      expected = %{
        id: "id",
        parent: [%{childA: "childA", childB: nil}, %{childA: nil, childB: "childB"}]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "empty map grandparent", %{nested_maps_schema: schema} do
      payload = %{id: "id", grandParent: %{}}

      expected = %{
        id: "id",
        grandParent: nil
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "map with empty map", %{nested_maps_schema: schema} do
      payload = %{id: "id", grandParent: %{parent: %{}}}

      expected = %{
        id: "id",
        grandParent: %{parent: nil}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "map with partial map", %{nested_maps_schema: schema} do
      payload = %{id: "id", grandParent: %{parent: %{childA: "childA"}}}

      expected = %{
        id: "id",
        grandParent: %{parent: %{childA: "childA", childB: nil}}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end
  end
end
