defmodule Andi.InputSchemas.DatasetSchemaValidatorTest do
  use ExUnit.Case

  alias Andi.InputSchemas.DatasetSchemaValidator

  describe "schema validation" do
    test "selectors are not required for non-xml schemas" do
      schema = [%{name: "field_name"}, %{name: "other_field", selector: "selector"}]

      errors = DatasetSchemaValidator.validate(schema, "application/json")
      assert Enum.empty?(errors)
    end

    test "xml source format requires a single field in the schema to have a selector" do
      schema = [
        %{name: "field_name"}
      ]

      errors = DatasetSchemaValidator.validate(schema, "text/xml")
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("selector")
    end

    test "runs xml specific validation when source type is an extension and not a mime type" do
      schema = [
        %{name: "field_name"}
      ]

      errors = DatasetSchemaValidator.validate(schema, "xml")
      assert length(errors) == 1
      assert List.first(errors) |> String.contains?("selector")
    end

    test "xml source format returns no errors when all fields have selectors" do
      schema = [
        %{name: "field_name", selector: "selector1"},
        %{name: "other_field", selector: "selector2"}
      ]

      errors = DatasetSchemaValidator.validate(schema, "text/xml")
      assert Enum.empty?(errors)
    end

    test "xml source format requires all fields in the schema to have selectors" do
      schema = [
        %{name: "field_name"},
        %{name: "other_field", selector: "this is the only selector"},
        %{name: "another_field", selector: ""}
      ]

      errors = DatasetSchemaValidator.validate(schema, "xml")
      assert length(errors) == 2
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+field_name/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+another_field/) end)
    end

    test "xml source format requires all fields in a nested schema to have selectors" do
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

      errors = DatasetSchemaValidator.validate(schema, "xml")
      assert length(errors) == 3
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_field/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_map/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deeper_field/) end)
    end

    test "xml source format requires all fields in a nested schema with lists to have selectors" do
      schema = [
        %{name: "other_field", type: "list", itemType: "string"},
        %{
          name: "another_field",
          type: "list",
          selector: "bob",
          itemType: "map",
          subSchema: [
            %{name: "deep_field"}
          ]
        }
      ]

      errors = DatasetSchemaValidator.validate(schema, "xml")
      assert length(errors) == 2
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+other_field/) end)
      assert errors |> Enum.any?(fn error -> String.match?(error, ~r/selector.+deep_field/) end)
    end
  end
end
