defmodule AndiWeb.DatasetValidatorTest do
  use ExUnit.Case
  use Placebo

  alias AndiWeb.DatasetValidator

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "validate/1 catches invalid datasets" do
    test "rejects a dataset with dashes in the systemName" do
      dataset = TDG.create_dataset(technical: %{systemName: "some-cool-data__so-many-dashes"})

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("systemName")
    end

    test "rejects a dataset that is already defined" do
      existing_dataset = TDG.create_dataset([])
      new_dataset = %Dataset{existing_dataset | id: "new_dataset"}

      allow Brook.get_all_values!(any(), :dataset), return: [existing_dataset]

      assert {:invalid, errors} = DatasetValidator.validate(new_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("Existing")
    end
  end
end
