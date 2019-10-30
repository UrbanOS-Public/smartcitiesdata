defmodule AndiWeb.DatasetValidatorTest do
  use ExUnit.Case
  use Placebo

  alias AndiWeb.DatasetValidator

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "validate/1 catches invalid datasets" do
    test "rejects a dataset with dashes in the orgName" do
      dataset =
        TDG.create_dataset(
          technical: %{orgName: "some-cool-data"},
          business: %{description: "something", modifiedDate: "2019-10-14T17:30:16Z"}
        )

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("orgName")
    end

    test "rejects a dataset with dashes in the dataName" do
      dataset = TDG.create_dataset(technical: %{dataName: "so-many-dashes"})

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("dataName")
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

    test "rejects datasets which have invalid business.modifiedDate date times" do
      dataset = TDG.create_dataset([])

      invalid_dataset = put_in(dataset.business.modifiedDate, "13:13:13")

      assert {:invalid, errors} = DatasetValidator.validate(invalid_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("modifiedDate must be iso8601 formatted")
    end

    test "allows datasets to have blank business.modifiedDate datetimes" do
      dataset = TDG.create_dataset([])
      invalid_dataset = put_in(dataset.business.modifiedDate, "")

      assert :valid = DatasetValidator.validate(invalid_dataset)
    end

    test "rejects datasets which have only date values as business.modifiedDate" do
      dataset = TDG.create_dataset([])

      invalid_dataset = put_in(dataset.business.modifiedDate, "2019-01-01")

      assert {:invalid, errors} = DatasetValidator.validate(invalid_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("modifiedDate must be iso8601 formatted")
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
