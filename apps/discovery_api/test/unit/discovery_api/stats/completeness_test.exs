defmodule DiscoveryApi.Stats.CompletenessTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApi.Stats.DataHelper
  alias DiscoveryApi.Stats.Completeness

  setup do
    allow(RaptorService.list_access_groups_by_dataset(any(), any()), return: [])

    {:ok,
     model: DataHelper.create_model(),
     simple_model: DataHelper.create_simple_model(),
     simple_overrides: DataHelper.create_simple_dataset_overrides(),
     array_model: DataHelper.create_array_model()}
  end

  describe "reducer/2" do
    test "with empty accumulator" do
      model = DataHelper.create_real_model()

      row = %{
        "bikes_allowed" => 0,
        "block_id" => 343_104,
        "direction_id" => 0,
        "route_id" => 35,
        "service_id" => 1,
        "shape_id" => 46_111,
        "trip_headsign" => "35 DUBLIN GRANVILLE TO EASTON TRANSIT CENTER",
        "trip_id" => 635_098,
        "trip_short_name" => "",
        "wheelchair_accessible" => 0
      }

      expected = %{
        record_count: 1,
        fields: %{
          "bikes_allowed" => %{count: 1, required: false},
          "block_id" => %{count: 1, required: false},
          "direction_id" => %{count: 1, required: false},
          "route_id" => %{count: 1, required: false},
          "service_id" => %{count: 1, required: false},
          "shape_id" => %{count: 1, required: false},
          "trip_headsign" => %{count: 1, required: false},
          "trip_id" => %{count: 1, required: false},
          "trip_short_name" => %{count: 0, required: false},
          "wheelchair_accessible" => %{count: 1, required: false}
        }
      }

      assert expected == Completeness.calculate_stats_for_row(model, row, %{})
    end

    test "with missing columns", %{simple_model: model} do
      expected = %{
        record_count: 2,
        fields: %{
          "id" => %{required: true, count: 1},
          "designation" => %{required: false, count: 2},
          "age" => %{required: false, count: 1}
        }
      }

      row1 = %{"id" => "343", "designation" => "John Smith"}
      row2 = %{"id" => nil, "designation" => "Jane Doe", "age" => 55}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 model,
                 row2,
                 Completeness.calculate_stats_for_row(model, row1, %{})
               )
    end

    test "does not count empty values" do
      model = %{
        id: "123",
        schema: [
          %{name: "id", type: "string", required: true}
        ]
      }

      expected = %{
        record_count: 5,
        fields: %{
          "id" => %{required: true, count: 1}
        }
      }

      row1 = %{"id" => "343"}
      row2 = %{"id" => nil}
      row3 = %{"id" => ""}
      row4 = %{"id" => "  "}
      row5 = %{"id" => "\r\n "}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 model,
                 row5,
                 Completeness.calculate_stats_for_row(
                   model,
                   row4,
                   Completeness.calculate_stats_for_row(
                     model,
                     row3,
                     Completeness.calculate_stats_for_row(
                       model,
                       row2,
                       Completeness.calculate_stats_for_row(model, row1, %{})
                     )
                   )
                 )
               )
    end

    test "three messages", %{simple_model: model} do
      expected = %{
        record_count: 3,
        fields: %{
          "id" => %{required: true, count: 3},
          "designation" => %{required: false, count: 2},
          "age" => %{required: false, count: 0}
        }
      }

      row1 = %{"id" => "343", "designation" => "John Smith", "age" => nil}
      row2 = %{"id" => "123", "designation" => "Jane Doe", "age" => nil}
      row3 = %{"id" => "456", "designation" => nil, "age" => nil}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 model,
                 row3,
                 Completeness.calculate_stats_for_row(
                   model,
                   row2,
                   Completeness.calculate_stats_for_row(model, row1, %{})
                 )
               )
    end

    test "with arrays as columns", %{array_model: array_model} do
      row1 = %{"id" => "343", "designation" => ["hello", "world"]}
      row2 = %{"id" => nil, "designation" => nil, "age" => 55}

      expected = %{
        record_count: 2,
        fields: %{
          "id" => %{required: false, count: 1},
          "designation" => %{required: false, count: 1},
          "age" => %{required: false, count: 1}
        }
      }

      assert expected ==
               Completeness.calculate_stats_for_row(
                 array_model,
                 row2,
                 Completeness.calculate_stats_for_row(array_model, row1, %{})
               )
    end

    test "with missing columns in all rows", %{simple_model: model} do
      expected = %{
        record_count: 2,
        fields: %{
          "id" => %{required: true, count: 0},
          "designation" => %{required: false, count: 0},
          "age" => %{required: false, count: 0}
        }
      }

      row1 = %{}
      row2 = %{}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 model,
                 row2,
                 Completeness.calculate_stats_for_row(model, row1, %{})
               )
    end

    test "with nested schema accumulator", %{model: model} do
      row = %{
        "required field" => "123",
        "required parent field" => %{
          "required sub field" => "jim",
          "next_of_kin" => %{"required_sub_schema_field" => "bob"}
        }
      }

      expected = %{
        record_count: 1,
        fields: %{
          "required field" => %{required: true, count: 1},
          "optional field" => %{required: false, count: 0},
          "optional field2" => %{required: false, count: 0},
          "required parent field" => %{required: true, count: 1},
          "required parent field.required sub field" => %{required: true, count: 1},
          "required parent field.next_of_kin" => %{required: true, count: 1},
          "required parent field.next_of_kin.Not required" => %{
            required: false,
            count: 0
          },
          "required parent field.next_of_kin.required_sub_schema_field" => %{
            required: true,
            count: 1
          },
          "required parent field.next_of_kin.Not required not specified" => %{
            required: false,
            count: 0
          }
        }
      }

      assert expected == Completeness.calculate_stats_for_row(model, row, %{})
    end

    test "Looks up columns by their downcased values" do
      model = %{
        id: "123",
        schema: [
          %{name: "Id", type: "number", required: true},
          %{name: "Designation", type: "string", required: true}
        ]
      }

      row = %{
        "id" => 0,
        "designation" => "my_name"
      }

      expected = %{
        record_count: 1,
        fields: %{
          "Id" => %{count: 1, required: true},
          "Designation" => %{count: 1, required: true}
        }
      }

      assert expected == Completeness.calculate_stats_for_row(model, row, %{})
    end
  end
end
