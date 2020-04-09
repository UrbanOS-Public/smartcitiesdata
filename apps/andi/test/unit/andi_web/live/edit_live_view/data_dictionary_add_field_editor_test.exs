defmodule AndiWeb.EditLiveView.DataDictionaryAddFieldEditorTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Checkov

  alias AndiWeb.EditLiveView.DataDictionaryAddFieldEditor
  alias Andi.InputSchemas.InputConverter
  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_value: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_attributes: 3
    ]

  @url_path "/datasets/"

  describe "get_parent_ids/1" do
    test "given schema that has a single map field, returns a list with only that field" do
      schema_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{technical: %{schema: [%{name: "map_field", id: schema_field_id, type: "map"}]}})
        |> InputConverter.smrt_dataset_to_changeset()
        |> Ecto.Changeset.apply_changes()

      assert [{schema_field_id, "map_field"}] == DataDictionaryAddFieldEditor.get_parent_ids(dataset)
    end

    test "given schema that has a single list field, returns a list with only that field" do
      schema_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{technical: %{schema: [%{name: "list_field", id: schema_field_id, type: "list"}]}})
        |> InputConverter.smrt_dataset_to_changeset()
        |> Ecto.Changeset.apply_changes()

      assert [{schema_field_id, "list_field"}] == DataDictionaryAddFieldEditor.get_parent_ids(dataset)
    end

    test "given schema that has a string field, it returns a list without that field" do
      schema_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [%{name: "list_field", id: schema_field_id, type: "list"}, %{name: "string_field", id: "blah", type: "string"}]
          }
        })
        |> InputConverter.smrt_dataset_to_changeset()
        |> Ecto.Changeset.apply_changes()

      assert [{schema_field_id, "list_field"}] == DataDictionaryAddFieldEditor.get_parent_ids(dataset)
    end

    test "given schema that has a nested list field, it returns a list with that field and its parent" do
      technical_field_id = UUID.uuid4()
      schema_parent_field_id = UUID.uuid4()
      schema_child_field_id = UUID.uuid4()

      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "list_field_parent",
                id: schema_parent_field_id,
                type: "list",
                subSchema: [%{name: "list_field_child", id: schema_child_field_id, type: "list"}]
              }
            ]
          }
        })
        |> InputConverter.smrt_dataset_to_changeset()
        |> Ecto.Changeset.apply_changes()
        |> put_in([:technical, :id], technical_field_id)

      assert [{"Top Level", technical_field_id}, {"list_field_parent", schema_parent_field_id}, {"list_field_parent > list_field_child", schema_child_field_id}] ==
               DataDictionaryAddFieldEditor.get_parent_ids(dataset)
    end
  end
end
