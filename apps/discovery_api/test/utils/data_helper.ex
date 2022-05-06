defmodule DiscoveryApi.Stats.DataHelper do
  @moduledoc """
  Helper module to create datasets for tests
  """
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Data.Mapper
  alias DiscoveryApi.Test.Helper

  def create_model do
    {:ok, model} =
      TDG.create_dataset(%{
        id: "abc",
        technical: %{
          schema: [
            %{name: "required field", type: "string", required: true},
            %{name: "optional field", type: "string", required: false},
            %{name: "optional field2", type: "string"},
            %{
              name: "required parent field",
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
      })
      |> Mapper.to_data_model(Helper.create_schema_organization())

    model
  end

  def create_real_model do
    {:ok, model} =
      TDG.create_dataset(%{
        id: "8997475d-105b-47dd-adc5-14d618423878",
        technical: %{
          schema: real_dataset_schema()
        }
      })
      |> Mapper.to_data_model(Helper.create_schema_organization())

    model
  end

  def real_dataset_schema do
    [
      %{name: "bikes_allowed", type: "int", required: false},
      %{name: "block_id", type: "int", required: false},
      %{name: "direction_id", type: "int", required: false},
      %{name: "route_id", type: "int", required: false},
      %{name: "service_id", type: "int", required: false},
      %{name: "shape_id", type: "int", required: false},
      %{name: "trip_headsign", type: "string", required: false},
      %{name: "trip_id", type: "int", required: false},
      %{name: "trip_short_name", type: "string", required: false},
      %{name: "wheelchair_accessible", type: "int", required: false}
    ]
  end

  def create_simple_dataset_overrides do
    %{
      id: "123",
      technical: %{
        schema: [
          %{name: "id", type: "string", required: true},
          %{name: "designation", type: "string"},
          %{name: "age", type: "string"}
        ]
      }
    }
  end

  def create_array_dataset_overrides do
    %{
      id: "123",
      technical: %{
        schema: [
          %{name: "id", type: "string"},
          %{name: "designation", type: "list"},
          %{name: "age", type: "string"}
        ]
      }
    }
  end

  def create_simple_model do
    {:ok, model} =
      TDG.create_dataset(create_simple_dataset_overrides())
      |> Mapper.to_data_model(Helper.create_schema_organization())

    model
  end

  def create_array_model do
    {:ok, model} =
      TDG.create_dataset(create_array_dataset_overrides())
      |> Mapper.to_data_model(Helper.create_schema_organization())

    model
  end
end
