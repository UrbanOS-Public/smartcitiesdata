defmodule AndiWeb.DatasetValidatorTest do
  use ExUnit.Case
  use Placebo

  alias Andi.Services.DatasetRetrieval
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
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("orgName")
    end

    test "rejects a dataset with dashes in the dataName" do
      dataset =
        TDG.create_dataset(technical: %{dataName: "so-many-dashes"})
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(dataset)

      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("dataName")
    end

    test "rejects a dataset that is already defined" do
      existing_dataset = TDG.create_dataset([])

      new_dataset =
        %Dataset{
          existing_dataset
          | id: "new_dataset",
            business: %{description: "something", modifiedDate: "2019-10-14T17:30:16+0000"}
        }
        |> struct_to_map_with_string_keys()

      allow DatasetRetrieval.get_all!(), return: [existing_dataset]

      assert {:invalid, errors} = DatasetValidator.validate(new_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("Existing")
    end

    test "rejects datasets which have invalid business.modifiedDate date times" do
      dataset =
        TDG.create_dataset([])
        |> struct_to_map_with_string_keys()

      invalid_dataset = put_in(dataset["business"]["modifiedDate"], "13:13:13")

      assert {:invalid, errors} = DatasetValidator.validate(invalid_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("modifiedDate must be iso8601 formatted")
    end

    test "allows datasets to have blank business.modifiedDate datetimes" do
      dataset =
        TDG.create_dataset([])
        |> struct_to_map_with_string_keys()

      invalid_dataset = put_in(dataset["business"]["modifiedDate"], "")

      assert :valid = DatasetValidator.validate(invalid_dataset)
    end

    test "rejects datasets which have only date values as business.modifiedDate" do
      dataset =
        TDG.create_dataset([])
        |> struct_to_map_with_string_keys()

      invalid_dataset = put_in(dataset["business"]["modifiedDate"], "2019-01-01")

      assert {:invalid, errors} = DatasetValidator.validate(invalid_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("modifiedDate must be iso8601 formatted")
    end
  end

  describe "dataset description" do
    test "rejects dataset with no description" do
      no_description_dataset =
        TDG.create_dataset(business: %{description: "", modifiedDate: "2019-10-14T17:30:16+0000"})
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(no_description_dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("Description")
    end
  end

  describe "xml dataset validation" do
    @valid_xml_schema [
      %{name: "field_name", selector: "selector"},
      %{name: "other_field", selector: "other_selector"}
    ]

    test "requires topLevelSelector" do
      dataset =
        TDG.create_dataset(technical: %{sourceFormat: "xml", schema: @valid_xml_schema})
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("topLevelSelector")
    end

    test "validates topLevelSelector when xml" do
      dataset =
        TDG.create_dataset(
          technical: %{sourceFormat: "xml", topLevelSelector: "this/is/a/selector", schema: @valid_xml_schema}
        )
        |> struct_to_map_with_string_keys()

      assert :valid = DatasetValidator.validate(dataset)
    end

    test "requires a single field in the schema to have a selector" do
      schema = [
        %{name: "field_name"}
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("selector")
    end

    test "requires all fields in the schema to have selectors" do
      schema = [
        %{name: "field_name"},
        %{name: "other_field", selector: "this is the only selector"},
        %{name: "another_field", selector: ""}
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(dataset)
      assert length(errors) == 2
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+field_name/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+another_field/) end)
    end

    test "requires all fields in a nested schema to have selectors" do
      schema = [
        %{name: "other_field", selector: "some selector"},
        %{
          name: "another_field",
          selector: "bob",
          type: "map",
          subSchema: [
            %{name: "deep_field"},
            %{
              name: "deep_map",
              type: "map",
              subSchema: [
                %{name: "deeper_field"}
              ]
            }
          ]
        }
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      assert {:invalid, errors} = DatasetValidator.validate(dataset)
      assert length(errors) == 3
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_field/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_map/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deeper_field/) end)
    end
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
