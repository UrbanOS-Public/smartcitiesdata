defmodule Andi.InputSchemas.DataDictionaryFieldsTest do
  use ExUnit.Case
  # use Divo
  use Andi.DataCase

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.Datasets.Business
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools

  setup_all do
    Application.ensure_all_started(:andi)
    :ok
  end

  describe "add_field_to_parent/2" do
    setup do
      schema_parent_field_id = UUID.uuid4()
      schema_child_field_id = UUID.uuid4()

      dataset = TDG.create_dataset(%{
            technical: %{
              schema: [
                %{
                  name: "map_field_parent",
                  id: schema_parent_field_id,
                  type: "map",
                  subSchema: [
                    %{name: "map_field_child_list", id: schema_child_field_id, type: "list"},
                    %{name: "map_field_child_string", type: "string"}
                  ]
                }
              ]
            }
          })

      {:ok, andi_dataset} = Datasets.update(dataset)
      [
        dataset: andi_dataset
      ]
    end

    test "given field as a map, top level id (technical id) and top level bread crumb", %{dataset: dataset} do
      parent_ids = DataDictionaryFields.get_parent_ids(dataset)

      {top_level_bread_crumb, technical_id} = parent_ids |> hd()

      field_name = "my first field"
      field_type = "string"

      field_as_map = %{
        name: field_name,
        type: field_type,
        parent_id: technical_id
      }

      {:ok, field} = DataDictionaryFields.add_field_to_parent(field_as_map, top_level_bread_crumb)

      updated_dataset = Datasets.get(dataset.id)
      assert [
        _,
        %{
          name: ^field_name,
          type: ^field_type,
          bread_crumb: ^field_name
        }
      ] = updated_dataset.technical.schema
    end

    test "given field as a map, parent id and parent bread crumb", %{dataset: dataset} do
      parent_ids = DataDictionaryFields.get_parent_ids(dataset)

      {field_level_bread_crumb, parent_id} = parent_ids |> List.last()

      field_name = "my first field"
      field_type = "string"
      expected_field_breadcrumb = field_level_bread_crumb <> " > " <> field_name

      field_as_map = %{
        name: field_name,
        type: field_type,
        parent_id: parent_id
      }

      {:ok, field} = DataDictionaryFields.add_field_to_parent(field_as_map, field_level_bread_crumb)

      updated_dataset = Datasets.get(dataset.id)
      assert [
        %{
          subSchema: [
            %{
              subSchema: [
                %{
                  name: ^field_name,
                  type: ^field_type,
                  bread_crumb: ^expected_field_breadcrumb
                }
              ]
            } = _list_child_list_field,
            _list_child_string_field
          ]
        }
      ] = updated_dataset.technical.schema
    end
  end

  describe "get_parent_ids/1" do
    test "given an existing dataset with a nested schema" do
      schema_parent_field_id = UUID.uuid4()
      schema_child_field_id = UUID.uuid4()

      dataset = TDG.create_dataset(%{
        technical: %{
          schema: [
            %{
              name: "map_field_parent",
              id: schema_parent_field_id,
              type: "map",
              subSchema: [
                %{name: "map_field_child_list", id: schema_child_field_id, type: "list"},
                %{name: "map_field_child_string", type: "string"},
              ]
            }
          ]
        }
      })

      {:ok, andi_dataset} = Datasets.update(dataset)

      technical_id = andi_dataset.technical.id

      parent_ids = DataDictionaryFields.get_parent_ids(andi_dataset)

      assert parent_ids == [
        {"Top Level", technical_id},
        {"map_field_parent", schema_parent_field_id},
        {"map_field_parent > map_field_child_list", schema_child_field_id}
      ]
    end
  end
end
