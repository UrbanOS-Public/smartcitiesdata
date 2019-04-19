ExUnit.start()
Application.ensure_all_started(:faker)
Application.ensure_all_started(:placebo)

defmodule TestHelper do
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  def create_dataset do
    TDG.create_dataset(%{
      id: "abc",
      technical: %{
        schema: [
          %{name: "required field", type: "string", required: true},
          %{name: "optional field", type: "string", required: false},
          %{name: "optional field", type: "string"},
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
  end

  def create_simple_dataset_overrides do
    %{
      id: "123",
      technical: %{
        schema: [
          %{name: "id", type: "string", required: true},
          %{name: "name", type: "string"}
        ]
      }
    }
  end

  def create_simple_dataset do
    TDG.create_dataset(create_simple_dataset_overrides())
  end
end
