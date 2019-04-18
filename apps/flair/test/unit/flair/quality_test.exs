defmodule Flair.QualityTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "get list of required fields correctly" do
    test "get_schema/? returns correct schema for dataset_id" do
      overrides = %{
        technical: %{
          schema: [
            %{name: "required field", type: "string", required: true},
            %{name: "optional field", type: "string", required: false},
            %{name: "optional field2", type: "string"}
          ]
        }
      }

      dataset = TDG.create_dataset(overrides)
      allow(Dataset.get!(dataset.id), return: dataset)

      assert ["required field"] == Flair.Quality.get_required_fields(dataset.id)
    end
  end
end
