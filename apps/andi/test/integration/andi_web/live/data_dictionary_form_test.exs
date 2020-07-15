defmodule AndiWeb.DataDictionaryFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.ConnCase
  use Placebo

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_select: 2,
      get_all_select_options: 2,
      get_select_first_option: 2,
      get_text: 2,
      get_texts: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.FormTools

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"


  describe "data_dictionary_tree_view" do
    test "given a schema with no nesting it displays the three fields in a well-known (BEM) way", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "one",
                type: "string"
              },
              %{
                name: "two",
                type: "integer"
              },
              %{
                name: "three",
                type: "float"
              }
            ]
          }
        })

      {:ok, _} = Datasets.update(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert ["one", "two", "three"] == get_texts(html, ".data-dictionary-tree-field__name")
      assert ["string", "integer", "float"] == get_texts(html, ".data-dictionary-tree-field__type")
    end

    test "given a schema with nesting it displays the three fields in a well-known (BEM) way", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "one",
                type: "string"
              },
              %{
                name: "two",
                type: "map",
                subSchema: [
                  %{
                    name: "two-one",
                    type: "integer"
                  }
                ]
              },
              %{
                name: "three",
                type: "list",
                itemType: "map",
                subSchema: [
                  %{
                    name: "three-one",
                    type: "float"
                  },
                  %{
                    name: "three-two",
                    type: "map",
                    subSchema: [
                      %{
                        name: "three-two-one",
                        type: "string"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        })

      {:ok, _} = Datasets.update(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert ["one", "two", "two-one", "three", "three-one", "three-two", "three-two-one"] ==
               get_texts(html, ".data-dictionary-tree-field__name")

      assert ["two", "three", "three-two"] ==
               get_texts(html, ".data-dictionary-tree__field--expanded .data-dictionary-tree-field__name")

      assert ["two-one", "three-one", "three-two", "three-two-one"] ==
               get_texts(html, ".data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name")

      assert ["three-two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["string", "map", "integer", "list", "float", "map", "string"] == get_texts(html, ".data-dictionary-tree-field__type")
    end

    #TODO - do we need this
    # test "generates hidden inputs for fields that are not selected", %{conn: conn} do
    #   dataset =
    #     TDG.create_dataset(%{
    #       technical: %{
    #         schema: [
    #           %{
    #             name: "one",
    #             type: "list",
    #             itemType: "map",
    #             description: "description",
    #             subSchema: [
    #               %{
    #                 name: "one-one",
    #                 type: "string"
    #               }
    #             ]
    #           },
    #           %{
    #             name: "two",
    #             type: "map",
    #             description: "this is a map",
    #             subSchema: [
    #               %{
    #                 name: "two-one",
    #                 type: "integer"
    #               }
    #             ]
    #           }
    #         ]
    #       }
    #     })

    #   {:ok, _} = Datasets.update(dataset)

    #   assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

    #   assert Enum.empty?(find_elements(html, "input[type='hidden']#form_data_schema_0_description"))
    #   assert Enum.count(find_elements(html, "input[type='hidden']#form_data_schema_1_description")) > 0
    # end

    test "handles datasets with no schema fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}}) |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "handles datasets with empty schema fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote", schema: []}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end
  end

  describe "add dictionary field modal" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "one",
                type: "list",
                itemType: "string",
                description: "description",
                subSchema: [
                  %{
                    name: "one-one",
                    type: "string"
                  }
                ]
              },
              %{
                name: "two",
                type: "map",
                description: "this is a map",
                subSchema: [
                  %{
                    name: "two-one",
                    type: "integer"
                  }
                ]
              }
            ]
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)
      [dataset: andi_dataset]
    end

    test "adds field as a sub schema", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      html = render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      refute Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      assert [
               {"Top Level", _},
               {"one", field_one_id},
               {"two", _}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      assert {_, ["Top Level"]} = get_select_first_option(html, ".data-dictionary-add-field-editor__parent-id select")

      form_data = %{
        "field" => %{
          "name" => "Natty",
          "type" => "string",
          "parent_id" => field_one_id
        }
      }

      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "validate", form_data)
      render(data_dictionary_view)
      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "add_field", nil)
      html = render(data_dictionary_view)


      assert "Natty" == get_text(html, "#data_dictionary_tree_one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "adds field as part of top level schema", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      html = render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      refute Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      assert [
               {"Top Level", technical_id},
               {"one", _},
               {"two", _}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      assert {_, ["Top Level"]} = get_select_first_option(html, ".data-dictionary-add-field-editor__parent-id select")

      form_data = %{
        "field" => %{
          "name" => "Steeeeeeez",
          "type" => "string",
          "parent_id" => technical_id
        }
      }

      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "validate", form_data)
      render(data_dictionary_view)
      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "add_field", nil)

      html = render(data_dictionary_view)

      assert "Steeeeeeez" ==
               get_text(html, "#data_dictionary_tree .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "dictionary fields with changed types are eligible for adding a field to", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      updated_dataset_schema =
        dataset
        |> put_in([:technical, :schema, Access.at(0), :subSchema, Access.at(0), :type], "map")
        |> FormTools.form_data_from_andi_dataset()
        |> get_in([:technical, :schema])

      form_data = %{"schema" => updated_dataset_schema}

      render_change(data_dictionary_view, "validate", %{"data_dictionary_form_schema" => form_data})

      html = render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      assert [
               {"Top Level", technical_id},
               {"one", _},
               {"two", _},
               {"one > one-one", new_eligible_parent_id}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      add_field_form_data = %{
        "field" => %{
          "name" => "Jared",
          "type" => "integer",
          "parent_id" => new_eligible_parent_id
        }
      }

      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "validate", add_field_form_data)
      render(data_dictionary_view)
      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "add_field", nil)

      html = render(data_dictionary_view)

      assert "Jared" ==
               get_text(html, "#data_dictionary_tree_one_one-one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "cancels back to modal not being visible", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      render_click([data_dictionary_view, "data_dictionary_add_field_editor"], "cancel", %{})

      html = render(data_dictionary_view)

      assert nil == get_value(html, ".data-dictionary-add-field-editor__name input")

      assert [] == get_select(html, ".data-dictionary-add-field-editor__type select")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end
  end

  describe "remove dictionary field modal" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "one",
                type: "string",
                description: "description"
              },
              %{
                name: "two",
                type: "map",
                description: "this is a map",
                subSchema: [
                  %{
                    name: "two-one",
                    type: "integer"
                  }
                ]
              }
            ]
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)
      [dataset: andi_dataset]
    end

    test "removes non parent field from subschema", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      html = render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(data_dictionary_view)
      selected_field_name = "one"

      refute selected_field_name in get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name")
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "removing a field selects the next sibling", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(data_dictionary_view)

      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "removes parent field along with its children", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], &List.delete_at(&1, 0))
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "true"})
      html = render(data_dictionary_view)

      assert "WARNING! Removing this field will also remove its children. Would you like to continue?" ==
               get_text(html, ".data-dicitionary-remove-field-editor__message")

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(data_dictionary_view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "no field is selected when the schema is empty", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], &List.delete_at(&1, 1))
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(data_dictionary_view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "no field is selected when subschema is empty", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      child_target = get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-target") |> List.last()
      child_id = get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-value-field-id") |> List.last()

      render_click([data_dictionary_view, child_target], "toggle_selected", %{
        "field-id" => child_id,
        "index" => nil,
        "name" => nil,
        "id" => nil
      })

      html = render(data_dictionary_view)

      assert "two-one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(data_dictionary_view)

      assert "" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      html = render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "cannot remove field when none is selected", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], fn _ -> [] end)
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "shows error message when ecto delete fails", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--hidden"))

      [selected_field_id] =
        get_attributes(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__text", "phx-value-field-id")

      assert {:ok, _} = DataDictionaryFields.remove_field(selected_field_id)

      render_click([data_dictionary_view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(data_dictionary_view)

      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--visible"))
    end
  end
end
