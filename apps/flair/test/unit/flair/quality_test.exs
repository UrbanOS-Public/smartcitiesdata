defmodule Flair.QualityTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "get list of required fields correctly" do
    test "get_required_fields/1  returns nested required fields for dataset_id" do
      overrides = %{
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

      dataset = TDG.create_dataset(overrides)
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
end
