ExUnit.start()
Application.ensure_all_started(:faker)
Application.ensure_all_started(:placebo)

defmodule TestHelper do
  alias SmartCity.TestDataGenerator, as: TDG

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
