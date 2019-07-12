defmodule ValkyrieTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Valkyrie.Dataset
  alias SmartCity.Data

  describe "validate_data/1" do
    test "validates strings successfully" do
      dataset = %Dataset{
        schema: [
          %{name: "name", type: "string"}
        ]
      }

      data = TDG.create_data(payload: %{"name" => "some string"})

      assert :ok == Valkyrie.validate_data(dataset, data)
    end
  end
end
