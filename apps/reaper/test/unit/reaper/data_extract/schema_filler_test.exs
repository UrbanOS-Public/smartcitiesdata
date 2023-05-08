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

      nested_list_schema = [
        %{name: "id", type: "string"},
        %{
          name: "grandParent",
          type: "list",
          itemType: "list",
          subSchema: [
            %{
              name: "parentList",
              type: "list",
              itemType: "string"
            }
          ]
        }
      ]

      [
        two_level_list_schema: two_level_list_schema,
        nested_maps_schema: nested_maps_schema,
        nested_list_schema: nested_list_schema
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

    test "empty list grandparent", %{nested_list_schema: schema} do
      payload = %{"id" => "id", "grandParent" => []}

      expected = %{
        "id" => "id",
        "grandParent" => []
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty parent list", %{nested_list_schema: schema} do
      payload = %{"id" => "id", "grandParent" => [[]]}

      expected = %{
        "id" => "id",
        "grandParent" => [[]]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nil grandParent list", %{nested_list_schema: schema} do
      payload = %{"id" => "id", "grandParent" => nil}

      expected = %{
        "id" => "id",
        "grandParent" => []
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nil parent list", %{nested_list_schema: schema} do
      payload = %{"id" => "id", "grandParent" => [nil]}

      expected = %{
        "id" => "id",
        "grandParent" => []
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nested list - no fill needed", %{nested_list_schema: schema} do
      payload = %{"id" => "id", "grandParent" => [["foo"]]}

      expected = %{
        "id" => "id",
        "grandParent" => [["foo"]]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end
  end

  describe "list of [list of maps of list of map of primitive] and [list of map of primitive]" do
    setup do
      complex_structure = [
        %{name: "id", type: "string"},
        %{
          name: "grandParentList",
          type: "list",
          itemType: "list",
          subSchema: [
            %{
              name: "parentList1",
              type: "list",
              itemType: "map",
              subSchema: [
                %{
                  name: "inner_list",
                  type: "list",
                  itemType: "map",
                  subSchema: [
                    %{name: "fieldA", type: "string"},
                    %{name: "fieldB", type: "string"}
                  ]
                },
                %{
                  name: "inner_list2",
                  type: "list",
                  itemType: "map",
                  subSchema: [
                    %{name: "fieldA", type: "string"},
                    %{name: "fieldB", type: "string"}
                  ]
                }
              ]
            }
          ]
        }
      ]

      [complex_structure: complex_structure]
    end

    #   test "empty first-level", %{complex_structure: schema} do
    #     payload = %{"id" => "id", "grandParentList" => []}

    #     expected = %{
    #       "id" => "id",
    #       "grandParent" => [
    #         [
    #           %{"inner_list" => [
    #             %{"fieldA" => nil},
    #             %{"fieldB" => nil}
    #             ]
    #           },
    #           %{"inner_list2" => [
    #             %{"fieldA" => nil},
    #             %{"fieldB" => nil}
    #           ]}
    #         ],
    #         [
    #           %{"fieldA" => nil},
    #           %{"fieldB" => nil}
    #         ]
    #       ]
    #     }

    #     actual = SchemaFiller.fill(schema, payload)

    #     assert expected == actual
    #   end
    # end

    test "empty grandParentList", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => []}

      expected = %{
        "id" => "id",
        "grandParentList" => []
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty parentList", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => [[], []]}

      expected = %{
        "id" => "id",
        "grandParentList" => [[], []]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nil parentList", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => [nil, []]}

      expected = %{
        "id" => "id",
        "grandParentList" => [[]]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty map inside parentList", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => [[%{}, %{}], [%{}, %{}]]}

      expected = %{
        "id" => "id",
        "grandParentList" => [[], []]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nil map inside parentList", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => [[nil]]}

      expected = %{
        "id" => "id",
        "grandParentList" => [[]]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "empty innerList and innerList2", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => [[%{"inner_list" => []}, %{"inner_list2" => []}]]}

      expected = %{
        "id" => "id",
        "grandParentList" => [
          [
            %{"inner_list" => [], "inner_list2" => []},
            %{"inner_list" => [], "inner_list2" => []}
          ]
        ]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "nil innerList without innerList2", %{complex_structure: schema} do
      payload = %{"id" => "id", "grandParentList" => [[%{"inner_list" => nil}]]}

      expected = %{
        "id" => "id",
        "grandParentList" => [[%{"inner_list" => [], "inner_list2" => []}]]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "Empty map inside inner list", %{complex_structure: schema} do
      payload = %{
        "id" => "id",
        "grandParentList" => [
          [
            %{"inner_list" => [%{}]}
          ],
          [
            %{"inner_list2" => [%{}]}
          ]
        ]
      }

      expected = %{
        "id" => "id",
        "grandParentList" => [
          [
            %{"inner_list" => [], "inner_list2" => []}
          ],
          [
            %{"inner_list" => [], "inner_list2" => []}
          ]
        ]
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end

    test "Partial map inside inner list", %{complex_structure: schema} do
      payload = %{
        "id" => "id",
        "grandParentList" => [
          [
            %{"inner_list" => [%{"fieldA" => "fieldA"}]}
          ],
          [
            %{"inner_list2" => [%{"fieldB" => "fieldB"}]}
          ]
        ]
      }

      expected = %{
        "id" => "id",
        "grandParentList" => [
          [
            %{
              "inner_list" => [
                %{"fieldA" => "fieldA", "fieldB" => nil}
              ],
              "inner_list2" => []
            }
          ],
          [
            %{
              "inner_list" => [],
              "inner_list2" => [
                %{"fieldA" => nil, "fieldB" => "fieldB"}
              ]
            }
          ]
        ]
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

      schema_with_list = [
        %{name: "id", type: "string", default: "123"},
        %{name: "designation", type: "list", itemType: "string"}
      ]

      [
        basic_schema: basic_schema,
        schema_with_list: schema_with_list
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

    test "missing key of list without default is filled with []", %{schema_with_list: schema} do
      payload = %{"id" => "456"}

      expected = %{
        "id" => "456",
        "designation" => []
      }

      actual = SchemaFiller.fill(schema, payload)

      assert expected == actual
    end
  end
end
