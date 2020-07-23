defmodule AndiWeb.DataDictionaryFormSchemaTest do
  use ExUnit.Case

  alias AndiWeb.InputSchemas.DataDictionaryFormSchema

  describe "changeset from file" do
    test "generates schema from parsed JSON" do
      parsed_file =
        [
          %{"top_level" => %{
               "level_one" => %{
                 "level_two" => []
               }
             }}
        ]

      changeset = DataDictionaryFormSchema.changeset_from_file(parsed_file, "123")

      assert changeset.valid?
    end

    test "adds bread crumbs to all fields" do
      parsed_file =
        [
          %{"parent1" => %{
               "child1" => []
             },
            "parent2" => 2
           }
        ]

      generated_schema = DataDictionaryFormSchema.generate_schema(parsed_file, "123")

      expected_schema = [
        %{
          "name" => "parent1",
          "bread_crumb" => "parent1",
          "type" => "map",
          "subSchema" => [
            %{
              "name" => "child1",
              "bread_crumb" => "parent1 > child1",
              "type" => "list"
            }
          ]
        },
        %{
          "bread_crumb" => "parent2",
          "name" => "parent2",
          "type" => "integer"
        }
      ]

      assert expected_schema == drop_fields_from_schema(generated_schema)
    end
  end

  defp drop_fields_from_schema(nil), do: nil

  defp drop_fields_from_schema(schema) do
    Enum.map(schema, fn field ->
      sub_schema = drop_fields_from_schema(field["subSchema"])
      case is_nil(sub_schema) do
        false -> %{"name" => field["name"], "bread_crumb" => field["bread_crumb"], "type" => field["type"], "subSchema" => sub_schema}
        true ->  %{"name" => field["name"], "bread_crumb" => field["bread_crumb"], "type" => field["type"]}
      end
    end)
  end
end
