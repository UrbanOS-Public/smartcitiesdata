defmodule AndiWeb.DatasetSchemaValidatorTest do
  use ExUnit.Case
  use Placebo

  alias AndiWeb.DatasetSchemaValidator
  alias SmartCity.TestDataGenerator, as: TDG

  describe "schema existance validation" do
    test "requires a schema to be present if the dataset source type is ingest" do
      dataset =
        TDG.create_dataset(technical: %{sourceType: "ingest", schema: [], topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("schema cannot be missing or empty")
    end

    test "requires a schema to be present if the dataset source type is stream" do
      dataset =
        TDG.create_dataset(technical: %{sourceType: "stream", schema: nil, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("schema cannot be missing or empty")
    end
  end

  describe "xml dataset validation" do
    test "requires a single field in the schema to have a selector" do
      schema = [
        %{name: "field_name"}
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceType: "ingest", sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("selector")
    end

    test "returns no errors when all fields have selectors" do
      schema = [
        %{name: "field_name", selector: "selector1"},
        %{name: "other_field", selector: "selector2"}
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceType: "ingest", sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
      assert length(errors) == 0
    end

    test "requires all fields in the schema to have selectors" do
      schema = [
        %{name: "field_name"},
        %{name: "other_field", selector: "this is the only selector"},
        %{name: "another_field", selector: ""}
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceType: "ingest", sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
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
        TDG.create_dataset(technical: %{sourceType: "ingest", sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
      assert length(errors) == 3
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_field/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_map/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deeper_field/) end)
    end

    test "requires all fields in a nested schema with lists to have selectors" do
      schema = [
        %{name: "other_field", type: "list", itemType: "string"},
        %{
          name: "another_field",
          type: "list",
          selector: "bob",
          itemType: "map",
          subSchema: [
            %{name: "deep_field"},
          ]
        }
      ]

      dataset =
        TDG.create_dataset(technical: %{sourceType: "ingest", sourceFormat: "xml", schema: schema, topLevelSelector: "this/is/a/selector"})
        |> struct_to_map_with_string_keys()

      errors = DatasetSchemaValidator.validate(dataset)
      assert length(errors) == 2
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+other_field/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_field/) end)
    end
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
