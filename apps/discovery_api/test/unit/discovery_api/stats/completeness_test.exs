defmodule DiscoveryApi.Stats.CompletenessTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApi.Stats.DataHelper
  alias DiscoveryApi.Stats.Completeness

  setup do
    {:ok,
     dataset: DataHelper.create_dataset(),
     simple_dataset: DataHelper.create_simple_dataset(),
     simple_overrides: DataHelper.create_simple_dataset_overrides(),
     array_dataset: DataHelper.create_array_dataset()}
  end

  describe "reducer/2" do
    test "with empty accumulator" do
      dataset = DataHelper.create_real_dataset()

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

      assert expected == Completeness.calculate_stats_for_row(dataset, row, %{})
    end

    test "with missing columns", %{simple_dataset: dataset} do
      expected = %{
        record_count: 2,
        fields: %{
          "id" => %{required: true, count: 1},
          "name" => %{required: false, count: 2},
          "age" => %{required: false, count: 1}
        }
      }

      row1 = %{"id" => "343", "name" => "John Smith"}
      row2 = %{"id" => nil, "name" => "Jane Doe", "age" => 55}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 dataset,
                 row2,
                 Completeness.calculate_stats_for_row(dataset, row1, %{})
               )
    end

    test "does not count empty values" do
      dataset = %{
        id: "123",
        technical: %{
          schema: [
            %{name: "id", type: "string", required: true}
          ]
        }
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
                 dataset,
                 row5,
                 Completeness.calculate_stats_for_row(
                   dataset,
                   row4,
                   Completeness.calculate_stats_for_row(
                     dataset,
                     row3,
                     Completeness.calculate_stats_for_row(
                       dataset,
                       row2,
                       Completeness.calculate_stats_for_row(dataset, row1, %{})
                     )
                   )
                 )
               )
    end

    test "three messages", %{simple_dataset: dataset} do
      expected = %{
        record_count: 3,
        fields: %{
          "id" => %{required: true, count: 3},
          "name" => %{required: false, count: 2},
          "age" => %{required: false, count: 0}
        }
      }

      row1 = %{"id" => "343", "name" => "John Smith", "age" => nil}
      row2 = %{"id" => "123", "name" => "Jane Doe", "age" => nil}
      row3 = %{"id" => "456", "name" => nil, "age" => nil}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 dataset,
                 row3,
                 Completeness.calculate_stats_for_row(
                   dataset,
                   row2,
                   Completeness.calculate_stats_for_row(dataset, row1, %{})
                 )
               )
    end

    test "with arrays as columns", %{array_dataset: array_dataset} do
      row1 = %{"id" => "343", "name" => ["hello", "world"]}
      row2 = %{"id" => nil, "name" => nil, "age" => 55}

      expected = %{
        record_count: 2,
        fields: %{
          "id" => %{required: false, count: 1},
          "name" => %{required: false, count: 1},
          "age" => %{required: false, count: 1}
        }
      }

      assert expected ==
               Completeness.calculate_stats_for_row(
                 array_dataset,
                 row2,
                 Completeness.calculate_stats_for_row(array_dataset, row1, %{})
               )
    end

    test "with missing columns in all rows", %{simple_dataset: dataset} do
      expected = %{
        record_count: 2,
        fields: %{
          "id" => %{required: true, count: 0},
          "name" => %{required: false, count: 0},
          "age" => %{required: false, count: 0}
        }
      }

      row1 = %{}
      row2 = %{}

      assert expected ==
               Completeness.calculate_stats_for_row(
                 dataset,
                 row2,
                 Completeness.calculate_stats_for_row(dataset, row1, %{})
               )
    end

    test "with nested schema accumulator", %{dataset: dataset} do
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

      assert expected == Completeness.calculate_stats_for_row(dataset, row, %{})
    end

    test "Looks up columns by their downcased values" do
      dataset = %{
        id: "123",
        technical: %{
          schema: [
            %{name: "Id", type: "number", required: true},
            %{name: "Name", type: "string", required: true}
          ]
        }
      }

      row = %{
        "id" => 0,
        "name" => "my_name"
      }

      expected = %{
        record_count: 1,
        fields: %{
          "Id" => %{count: 1, required: true},
          "Name" => %{count: 1, required: true}
        }
      }

      assert expected == Completeness.calculate_stats_for_row(dataset, row, %{})
    end
  end
end
