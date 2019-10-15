defmodule AndiWeb.DatasetValidatorTest do
  use ExUnit.Case
  use Placebo

  alias AndiWeb.DatasetValidator

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "validate/1 catches invalid datasets" do
    test "rejects a dataset with dashes in the systemName" do
      dataset =
        TDG.create_dataset(
          technical: %{systemName: "some-cool-data__so-many-dashes"},
          business: %{description: "something", modifiedDate: "2019-10-14T17:30:16+0000"}
        )

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("systemName")
    end

    test "rejects a dataset that is already defined" do
      existing_dataset = TDG.create_dataset([])

      new_dataset = %Dataset{
        existing_dataset
        | id: "new_dataset",
          business: %{description: "something", modifiedDate: "2019-10-14T17:30:16+0000"}
      }

      allow Brook.get_all_values!(any(), :dataset), return: [existing_dataset]

      assert {:invalid, errors} = DatasetValidator.validate(new_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("Existing")
    end
  end

  describe "modified_date_iso8601/1 checks date format" do
    test "accepts null string as a valid format" do
      dataset = TDG.create_dataset(business: %{modifiedDate: ""})

      assert :valid = DatasetValidator.validate(dataset)
    end

    test "accepts valid date when in iso8601 format" do
      dataset = TDG.create_dataset(business: %{description: "something", modifiedDate: "2019-10-14T17:30:16+0000"})

      assert :valid = DatasetValidator.validate(dataset)
    end

    test "rejects dates and strings that are in other formats" do
      dataset = TDG.create_dataset(business: %{description: "something", modifiedDate: "2019-10-14T17"})

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("modifiedDate")
    end
  end

  describe "dataset description" do
    test "rejects dataset with no description" do
      no_description_dataset =
        TDG.create_dataset(business: %{description: "", modifiedDate: "2019-10-14T17:30:16+0000"})

      assert {:invalid, errors} = DatasetValidator.validate(no_description_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("Description")
    end
  end
end
