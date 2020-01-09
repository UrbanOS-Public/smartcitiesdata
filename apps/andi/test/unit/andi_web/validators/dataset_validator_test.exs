defmodule AndiWeb.DatasetValidatorTest do
  use ExUnit.Case
  use Placebo

  alias Andi.Services.DatasetRetrieval
  alias AndiWeb.DatasetValidator

  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  describe "xml dataset validation" do
    @valid_xml_schema [
      %{name: "field_name", selector: "selector"},
      %{name: "other_field", selector: "other_selector"}
    ]
    test "requires fields in the schema to have a selector" do
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
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
