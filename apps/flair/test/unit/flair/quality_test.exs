defmodule Flair.QualityTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  alias Flair.Quality

  setup do
    dataset_overrides = %{
      id: "123",
      technical: %{
        schema: [
          %{name: "required field", type: "string", required: true},
          %{name: "optional field", type: "string", required: false},
          %{name: "optional field", type: "string"},
          %{
            name: "required nested field",
            type: "map",
            required: true,
            subSchema: [
              %{name: "required sub field", type: "string", required: true},
              %{
                name: "next_of_kin",
                type: "map",
                required: true,
                subSchema: [
                  %{name: "Not required", type: "string", required: false},
                  %{name: "required_sub_schema_field", type: "date", required: true},
                  %{name: "Not required not specified", type: "string"}
                ]
              }
            ]
          }
        ]
      }
    }

    dataset = TDG.create_dataset(dataset_overrides)

    simple_dataset_overrides =
      dataset_overrides = %{
        id: "123",
        technical: %{
          schema: [
            %{name: "id", type: "string", required: true},
            %{name: "name", type: "string"}
          ]
        }
      }

    simple_dataset = TDG.create_dataset(simple_dataset_overrides)

    {:ok,
     dataset: dataset, simple_dataset: simple_dataset, simple_overrides: simple_dataset_overrides}
  end

  describe "get list of required fields correctly" do
    test "get_required_fields/1 returns nested required fields for dataset_id", %{
      dataset: dataset
    } do
      allow(Dataset.get!(dataset.id), return: dataset)

      assert [
               "required field",
               "required sub field",
               "required_sub_schema_field",
               "next_of_kin",
               "required nested field"
             ] ==
               Flair.Quality.get_required_fields(dataset.id)
    end

    test "get_required_fields/1 does not return nested required fields whose parent is optional" do
      overrides = %{
        technical: %{
          schema: [
            %{name: "required field", type: "string", required: true},
            %{
              name: "optional parent field",
              type: "map",
              subSchema: [
                %{name: "required sub field", type: "string", required: true}
              ]
            }
          ]
        }
      }

      dataset = TDG.create_dataset(overrides)
      allow(Dataset.get!(dataset.id), return: dataset)

      assert ["required field"] == Flair.Quality.get_required_fields(dataset.id)
    end

    test "get_required_fields/1 does not return when there are no required fields" do
      overrides = %{
        technical: %{
          schema: [
            %{name: "optional parent field", type: "string", required: false},
            %{
              name: "optional parent field",
              type: "map",
              subSchema: [
                %{name: "optional sub field", type: "string"}
              ]
            }
          ]
        }
      }

      dataset = TDG.create_dataset(overrides)
      allow(Dataset.get!(dataset.id), return: dataset)

      assert [] == Flair.Quality.get_required_fields(dataset.id)
    end
  end

  describe "quality_reducer" do
    test "with empty accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      expected = %{"123" => %{:record_count => 1, "id" => 1}}

      allow(Dataset.get!(dataset.id), return: dataset)
      assert expected == Quality.reducer(data, %{})
    end

    test "with existing accumulator", %{simple_dataset: dataset} do
      data_override = %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}}

      data = TDG.create_data(data_override)

      allow(Dataset.get!(dataset.id), return: dataset)

      assert %{"123" => %{:record_count => 2, "id" => 2}} ==
               Quality.reducer(data, Quality.reducer(data, %{}))
    end

    test "three messages", %{simple_dataset: dataset} do
      data_overrides = [
        %{dataset_id: "123", payload: %{"id" => "123", "name" => "John Smith"}},
        %{dataset_id: "123", payload: %{"name" => "John Smith"}},
        %{dataset_id: "123", payload: %{"id" => "123"}}
      ]

      messages =
        data_overrides
        |> Enum.map(fn override -> TDG.create_data(override) end)

      allow(Dataset.get!(dataset.id), return: dataset)

      assert %{"123" => %{:record_count => 3, "id" => 2}} ==
               Enum.reduce(messages, %{}, &Quality.reducer/2)
    end

    test "different dataset_ids", %{simple_dataset: dataset, simple_overrides: simple_overrides} do
      data_overrides = [
        %{dataset_id: "456", payload: %{"id" => "123", "name" => "George Lucas"}},
        %{dataset_id: "123", payload: %{"name" => "John Williams"}},
        %{dataset_id: "789", payload: %{"id" => "123"}}
      ]

      messages =
        data_overrides
        |> Enum.map(fn override -> TDG.create_data(override) end)

      dataset2 = TDG.create_dataset(simple_overrides) |> Map.put(:id, "456")
      dataset3 = TDG.create_dataset(simple_overrides) |> Map.put(:id, "789")

      allow(Dataset.get!("123"), return: dataset)
      allow(Dataset.get!("456"), return: dataset2)
      allow(Dataset.get!("789"), return: dataset3)

      expected = %{
        "456" => %{:record_count => 1, "id" => 1},
        "123" => %{:record_count => 1, "id" => 0},
        "789" => %{:record_count => 1, "id" => 1}
      }

      assert expected ==
               Enum.reduce(messages, %{}, &Quality.reducer/2)
    end
  end
end
