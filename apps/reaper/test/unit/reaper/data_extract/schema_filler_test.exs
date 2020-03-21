defmodule Reaper.DataExtract.SchemaFillerTest do
  use ExUnit.Case
  doctest SmartCity.Helpers
  alias Reaper.DataExtract.SchemaFiller

  describe "single level" do
    setup do
      basic_schema = [
        %{name: "id", type: "string"},
        %{
          name: "parentMap",
          type: "map",
          subSchema: [%{name: "fieldA", type: "string"}, %{name: "fieldB", type: "string"}]
        }
      ]

      list_schema = [
        %{name: "id", type: "string"},
        %{
          name: "parentList",
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
      payload = %{"id" => "id", "parentMap" => nil}

      expected = %{
        "id" => "id",
        "parentMap" => %{"fieldA" => nil, "fieldB" => nil}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty map", %{basic_schema: schema} do
      payload = %{"id" => "id", "parentMap" => %{}}

      expected = %{
        "id" => "id",
        "parentMap" => %{"fieldA" => nil, "fieldB" => nil}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "partial map", %{basic_schema: schema} do
      payload = %{"id" => "id", "parentMap" => %{"fieldA" => "fieldA"}}

      expected = %{
        "id" => "id",
        "parentMap" => %{"fieldA" => "fieldA", "fieldB" => nil}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty list", %{list_schema: schema} do
      payload = %{"id" => "id", "parentList" => []}

      expected = %{
        "id" => "id",
        "parentList" => []
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with string item", %{list_schema: schema} do
      payload = %{"id" => "id", "parentList" => ["thing"]}

      expected = %{
        "id" => "id",
        "parentList" => ["thing"]
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
          name: "parentList",
          type: "list",
          itemType: "map",
          subSchema: [%{name: "fieldA", type: "string"}, %{name: "fieldB", type: "string"}]
        }
      ]

      nested_maps_schema = [
        %{name: "id", type: "string"},
        %{
          name: "grandParent",
          type: "map",
          subSchema: [
            %{
              name: "parentMap",
              type: "map",
              subSchema: [%{name: "fieldA", type: "string"}, %{name: "fieldB", type: "string"}]
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
      payload = %{"id" => "id", "parentList" => [%{}]}

      expected = %{
        "id" => "id",
        "parentList" => []
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with nil", %{two_level_list_schema: schema} do
      payload = %{"id" => "id", "parentList" => [nil]}

      expected = %{
        "id" => "id",
        "parentList" => []
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with one good value and two ignored values", %{two_level_list_schema: schema} do
      payload = %{"id" => "id", "parentList" => [%{}, %{"fieldA" => "child"}, nil]}

      expected = %{
        "id" => "id",
        "parentList" => [%{"fieldA" => "child", "fieldB" => nil}]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with partial map", %{two_level_list_schema: schema} do
      payload = %{"id" => "id", "parentList" => [%{"fieldA" => "fieldA"}]}

      expected = %{
        "id" => "id",
        "parentList" => [%{"fieldA" => "fieldA", "fieldB" => nil}]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "list with 2 partial maps", %{two_level_list_schema: schema} do
      payload = %{"id" => "id", "parentList" => [%{"fieldA" => "fieldA"}, %{"fieldB" => "fieldB"}]}

      expected = %{
        "id" => "id",
        "parentList" => [%{"fieldA" => "fieldA", "fieldB" => nil}, %{"fieldA" => nil, "fieldB" => "fieldB"}]
      }

      actual = SchemaFiller.fill(schema, payload)
      assert expected == actual
    end

    test "empty map grandparent", %{nested_maps_schema: schema} do
      payload = %{"id" => "id", "grandParent" => %{}}

      expected = %{
        "id" => "id",
        "grandParent" => %{"parentMap" => %{"fieldA" => nil, "fieldB" => nil}}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "map with empty map", %{nested_maps_schema: schema} do
      payload = %{"id" => "id", "grandParent" => %{"parentMap" => %{}}}

      expected = %{
        "id" => "id",
        "grandParent" => %{"parentMap" => %{"fieldA" => nil, "fieldB" => nil}}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "map with partial map", %{nested_maps_schema: schema} do
      payload = %{"id" => "id", "grandParent" => %{"parentMap" => %{"fieldA" => "fieldA"}}}

      expected = %{
        "id" => "id",
        "grandParent" => %{"parentMap" => %{"fieldA" => "fieldA", "fieldB" => nil}}
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end
  end

  describe "default values" do
    setup do
      basic_schema = [
        %{name: "id", type: "string", default: "123"},
        %{name: "designation", type: "string"}
      ]

      [
        basic_schema: basic_schema
      ]
    end

    test "missing key is filled with default value", %{basic_schema: schema} do
      payload = %{"designation" => "frank"}

      expected = %{
        "id" => "123",
        "designation" => "frank"
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nil field is filled with default value", %{basic_schema: schema} do
      payload = %{"id" => nil, "designation" => "frank"}

      expected = %{
        "id" => "123",
        "designation" => "frank"
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "missing key without default is filled with nil", %{basic_schema: schema} do
      payload = %{"id" => "456"}

      expected = %{
        "id" => "456",
        "designation" => nil
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end
  end
end
