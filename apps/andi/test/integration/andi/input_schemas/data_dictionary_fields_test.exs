defmodule Andi.InputSchemas.DataDictionaryFieldsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.DataDictionaryFields

  describe "add_field_to_parent/2" do
    setup do
      schema_parent_field_id = UUID.uuid4()
      schema_child_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "map_field_parent",
                id: schema_parent_field_id,
                type: "map",
                subSchema: [
                  %{name: "map_field_child_list", id: schema_child_field_id, type: "list", itemType: "string"},
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
        ingestion_field_selector: field_name,
        parent_id: technical_id,
        dataset_id: dataset.id
      }

      {:ok, _field} = DataDictionaryFields.add_field_to_parent(field_as_map, top_level_bread_crumb)

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
        ingestion_field_selector: field_name,
        parent_id: parent_id,
        dataset_id: dataset.id
      }

      {:ok, _field} = DataDictionaryFields.add_field_to_parent(field_as_map, field_level_bread_crumb)

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

    test "given an invalid field as a map, it returns an error tuple with a changeset that reflects the original change", %{
      dataset: dataset
    } do
      parent_ids = DataDictionaryFields.get_parent_ids(dataset)

      {top_level_bread_crumb, technical_id} = parent_ids |> hd()

      field_name = ""
      field_type = ""

      field_as_map = %{
        name: field_name,
        type: field_type,
        parent_id: technical_id,
        dataset_id: dataset.id
      }

      {:error, changeset} = DataDictionaryFields.add_field_to_parent(field_as_map, top_level_bread_crumb)

      refute changeset.valid?

      bad_field = Ecto.Changeset.apply_changes(changeset)

      assert bad_field.technical_id == nil
      assert bad_field.parent_id == technical_id
    end

    test "allows adding date field with no format", %{dataset: dataset} do
      parent_ids = DataDictionaryFields.get_parent_ids(dataset)

      {top_level_bread_crumb, technical_id} = parent_ids |> hd()

      field_as_map = %{
        name: "cam",
        type: "date",
        ingestion_field_selector: "cam",
        parent_id: technical_id,
        dataset_id: dataset.id
      }

      {:ok, _field} = DataDictionaryFields.add_field_to_parent(field_as_map, top_level_bread_crumb)
    end
  end

  describe "get_parent_ids/1" do
    test "given an existing dataset with a nested schema" do
      schema_parent_field_id = UUID.uuid4()
      schema_child_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "map_field_parent",
                id: schema_parent_field_id,
                type: "map",
                subSchema: [
                  %{name: "map_field_child_list", id: schema_child_field_id, type: "list", itemType: "string"},
                  %{name: "map_field_child_string", type: "string"}
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
