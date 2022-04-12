defmodule AndiWeb.EditIngestionLiveView.DataDictionaryFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  import Phoenix.LiveViewTest

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.Helpers.FormTools

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

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  @url_path "/ingestions/"

  describe "data_dictionary_tree_view" do
    test "given a schema with no nesting it displays the three fields in a well-known (BEM) way",
         %{conn: conn} do
      schema = [
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

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      assert ["one", "two", "three"] == get_texts(html, ".data-dictionary-tree-field__name")

      assert ["string", "integer", "float"] ==
               get_texts(html, ".data-dictionary-tree-field__type")
    end

    test "given a schema with nesting it displays the three fields in a well-known (BEM) way", %{
      conn: conn
    } do
      schema = [
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

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      assert ["one", "two", "two-one", "three", "three-one", "three-two", "three-two-one"] ==
               get_texts(html, ".data-dictionary-tree-field__name")

      assert ["two", "three", "three-two"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__field--expanded .data-dictionary-tree-field__name"
               )

      assert ["two-one", "three-one", "three-two", "three-two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["three-two-one"] ==
               get_texts(
                 html,
                 ".data-dictionary-tree__sub-dictionary .data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name"
               )

      assert ["string", "map", "integer", "list", "float", "map", "string"] ==
               get_texts(html, ".data-dictionary-tree-field__type")
    end

    test "generates hidden inputs for fields that are not selected", %{conn: conn} do
      schema = [
        %{
          name: "one",
          type: "list",
          itemType: "map",
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

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      assert Enum.empty?(
               find_elements(
                 html,
                 "input[type='hidden']#data_dictionary_form_schema_schema_0_description"
               )
             )

      assert Enum.count(
               find_elements(
                 html,
                 "input[type='hidden']#data_dictionary_form_schema_schema_1_description"
               )
             ) > 0
    end

    test "displays help for ingestions with empty schema fields", %{conn: conn} do
      ingestion = create_ingestion_with_schema([])

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      assert get_text(html, ".data-dictionary-tree__getting-started-help") =~ "add a new field"
    end

    test "does not display help for ingestions with empty subschema fields", %{conn: conn} do
      schema = [
        %{
          name: "one",
          type: "map",
          subSchema: []
        }
      ]

      ingestion = create_ingestion_with_schema(schema)

      assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

      refute get_text(html, ".data-dictionary-tree__getting-started-help") =~ "add a new field"
    end
  end

  describe "add dictionary field modal" do
    setup do
      ingestion =
        create_ingestion_with_schema([
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
        ])

      [ingestion: ingestion]
    end

    test "adds field as a sub schema", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      html = render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      refute Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      assert [
               {"Top Level", _},
               {"one", field_one_id},
               {"two", _}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      assert {_, ["Top Level"]} =
               get_select_first_option(
                 html,
                 ".data-dictionary-add-field-editor__parent-id select"
               )

      form_data = %{
        "field" => %{
          "name" => "Natty",
          "type" => "string",
          "parent_id" => field_one_id
        }
      }

      form = element(data_dictionary_view, "#data_dictionary_add_field_editor form")

      add_button = element(data_dictionary_view, "#data_dictionary_add_field_editor button", "ADD FIELD")

      render_change(form, form_data)
      render(data_dictionary_view)
      render_click(add_button)
      html = render(data_dictionary_view)

      assert "Natty" ==
               get_text(
                 html,
                 "#data_dictionary_tree_one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "adds field as part of top level schema", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      html = render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      refute Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      assert [
               {"Top Level", ingestion_id},
               {"one", _},
               {"two", _}
             ] = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      assert {_, ["Top Level"]} =
               get_select_first_option(
                 html,
                 ".data-dictionary-add-field-editor__parent-id select"
               )

      form_data = %{
        "field" => %{
          "name" => "Steeeeeeez",
          "type" => "string",
          "parent_id" => ingestion_id
        }
      }

      form = element(data_dictionary_view, "#data_dictionary_add_field_editor form")

      add_button = element(data_dictionary_view, "#data_dictionary_add_field_editor button", "ADD FIELD")

      render_change(form, form_data)
      render(data_dictionary_view)
      render_click(add_button)

      html = render(data_dictionary_view)

      assert "Steeeeeeez" ==
               get_text(
                 html,
                 "#data_dictionary_tree .data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "dictionary fields with changed types are eligible for adding a field to", %{
      conn: conn,
      ingestion: ingestion
    } do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      updated_ingestion_schema =
        ingestion
        |> put_in([:schema, Access.at(0), :subSchema, Access.at(0), :type], "map")
        |> FormTools.form_data_from_andi_ingestion()
        |> get_in([:schema])

      form_data = %{"schema" => updated_ingestion_schema}

      render_change(data_dictionary_view, "validate", %{
        "data_dictionary_form_schema" => form_data
      })

      html = render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      expected_options = [
        "Top Level",
        "one > one-one",
        "one",
        "two"
      ]

      select_options = get_all_select_options(html, ".data-dictionary-add-field-editor__parent-id select")

      Enum.each(select_options, fn {option_name, _} ->
        assert option_name in expected_options
      end)

      {_, new_eligible_parent_id} = List.keyfind(select_options, "one > one-one", 0)

      add_field_form_data = %{
        "field" => %{
          "name" => "Jared",
          "type" => "integer",
          "parent_id" => new_eligible_parent_id
        }
      }

      form = element(data_dictionary_view, "#data_dictionary_add_field_editor form")

      add_button = element(data_dictionary_view, "#data_dictionary_add_field_editor button", "ADD FIELD")

      render_change(form, add_field_form_data)
      render(data_dictionary_view)
      render_click(add_button)

      html = render(data_dictionary_view)

      assert "Jared" ==
               get_text(
                 html,
                 "#data_dictionary_tree_one_one-one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )
    end

    test "cancels back to modal not being visible", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      render_click(data_dictionary_view, "add_data_dictionary_field", %{})

      cancel_button = element(data_dictionary_view, "#data_dictionary_add_field_editor input.btn")
      render_click(cancel_button)

      html = render(data_dictionary_view)

      assert nil == get_value(html, ".data-dictionary-add-field-editor__name input")

      assert [] == get_select(html, ".data-dictionary-add-field-editor__type select")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end
  end

  describe "remove dictionary field modal" do
    setup do
      schema = [
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

      [ingestion: create_ingestion_with_schema(schema)]
    end

    test "removes non parent field from subschema", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      html = render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")

      render_click(delete_button)
      html = render(data_dictionary_view)
      selected_field_name = "one"

      refute selected_field_name in get_texts(
               html,
               ".data-dictionary-tree__field .data-dictionary-tree-field__name"
             )

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "two" ==
               get_text(
                 html,
                 ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )
    end

    test "removing a field selects the next sibling", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "one" ==
               get_text(
                 html,
                 ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")

      render_click(delete_button)
      html = render(data_dictionary_view)

      assert "two" ==
               get_text(
                 html,
                 ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )
    end

    test "removes parent field along with its children", %{conn: conn, ingestion: ingestion} do
      ingestion
      |> update_in([:schema], &List.delete_at(&1, 0))
      |> Ingestions.update()

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "two" ==
               get_text(
                 html,
                 ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")

      render_click(delete_button)
      html = render(data_dictionary_view)

      assert "WARNING! Removing this field will also remove its children. Would you like to continue?" ==
               get_text(html, ".data-dicitionary-remove-field-editor__message")

      render_click(delete_button)
      html = render(data_dictionary_view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "no field is selected when the schema is empty", %{conn: conn, ingestion: ingestion} do
      ingestion
      |> update_in([:schema], &List.delete_at(&1, 1))
      |> Ingestions.update()

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "one" ==
               get_text(
                 html,
                 ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name"
               )

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")

      render_click(delete_button)

      html = render(data_dictionary_view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))

      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "cannot remove field when none is selected", %{conn: conn, ingestion: ingestion} do
      ingestion
      |> update_in([:schema], fn _ -> [] end)
      |> Ingestions.update()

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "shows error message when ecto delete fails", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--hidden"))

      [selected_field_id] =
        get_attributes(
          html,
          ".data-dictionary-tree__field--selected .data-dictionary-tree-field__text",
          "phx-value-field-id"
        )

      assert {:ok, _} = DataDictionaryFields.remove_field(selected_field_id)

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")

      render_click(delete_button)

      html = render(data_dictionary_view)

      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--visible"))
    end
  end

  test "required schema field displays proper error message", %{conn: conn} do
    ingestion = create_ingestion_with_schema([])

    assert {:ok, _view, html} = live(conn, @url_path <> ingestion.id)

    assert get_text(html, "#schema-error-msg") == "Please add a field to continue"
  end

  @tag :skip
  describe "default timestamp/date" do
    setup do
      timestamp_schema = [%{name: "timestamp_field", type: "timestamp"}]
      date_schema = [%{name: "date_field", type: "date"}]
      andi_ingestion_with_timestamp = create_ingestion_with_schema(timestamp_schema)
      andi_ingestion_with_date = create_ingestion_with_schema(date_schema)

      [
        andi_ingestion_with_date: andi_ingestion_with_date,
        andi_ingestion_with_timestamp: andi_ingestion_with_timestamp
      ]
    end

    # todo: broken
    # field form data doesn't persist
    test "replaces provider with nil when use default checkbox is unselected", %{conn: conn} do
      schema = [
        %{
          name: "date_field",
          type: "date",
          default: %{provider: "date", version: "1", opts: %{offset_in_days: -1}}
        }
      ]

      andi_ingestion = create_ingestion_with_schema(schema)

      schema_field_id = andi_ingestion.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert ["checked"] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")

      assert get_value(html, "#data_dictionary_field_editor__offset_input") == "-1"

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion.id,
            "format" => "{YYYY}",
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id,
            "use_default" => "false",
            "offset" => "-1"
          }
        }
      }

      html =
        data_dictionary_view
        |> render_change("validate", %{"data_dictionary_form_schema" => form_schema})

      render_change(view, "save")

      eventually(
        fn ->
          updated_andi_ingestion = Ingestions.get(andi_ingestion.id)

          smrt_ingestion_from_andi_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(updated_andi_ingestion)

          updated_schema_field = smrt_ingestion_from_andi_ingestion.schema |> hd()

          refute Map.has_key?(updated_schema_field, :default)

          assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor__use-default", "checked"))

          assert ["disabled"] = get_attributes(html, "#data_dictionary_field_editor__offset_input", "disabled")
        end,
        20,
        200
      )
    end

    test "replaces nil provider with default when use default checkbox is checked", %{conn: conn} do
      schema = [%{name: "date_field", type: "date"}]
      andi_ingestion = create_ingestion_with_schema(schema)

      schema_field_id = andi_ingestion.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_ingestion.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor__use-default", "checked"))

      assert ["disabled"] = get_attributes(html, "#data_dictionary_field_editor__offset_input", "disabled")

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion.id,
            "format" => "{YYYY}",
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id,
            "use_default" => "true"
          }
        }
      }

      html =
        data_dictionary_view
        |> render_change("validate", %{"data_dictionary_form_schema" => form_schema})

      render_change(view, "save")

      eventually(
        fn ->
          updated_andi_ingestion = Ingestions.get(andi_ingestion.id)

          smrt_ingestion_from_andi_ingestion(InputConverter.andi_ingestion_to_smrt_ingestion(updated_andi_ingestion))

          updated_schema_field = smrt_ingestion_from_andi_ingestion.schema |> hd()

          assert ["checked"] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")

          assert %{provider: "date"} = Map.get(updated_schema_field, :default)
        end,
        20,
        100
      )
    end

    test "generates provision for timestamps", %{
      conn: conn,
      andi_ingestion_with_timestamp: andi_ingestion_with_timestamp
    } do
      schema_field_id = andi_ingestion_with_timestamp.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_ingestion_with_timestamp.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      format = "{YYYY}-{0M}-{0D}"
      offset_in_seconds = -1 * 60 * 60 * 24

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion_with_timestamp.id,
            "format" => format,
            "name" => "timestamp_field",
            "type" => "timestamp",
            "bread_crumb" => "timestamp_field",
            "id" => schema_field_id,
            "use_default" => "true",
            "default_offset" => offset_in_seconds
          }
        }
      }

      data_dictionary_view
      |> render_change("validate", %{"data_dictionary_form_schema" => form_schema})

      render_change(view, "save")

      eventually(
        fn ->
          updated_andi_ingestion = Ingestions.get(andi_ingestion_with_timestamp.id)

          smrt_ingestion_from_andi_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(updated_andi_ingestion)

          assert %{
                   default: %{
                     provider: "timestamp",
                     version: "2",
                     opts: %{
                       format: format,
                       offset_in_seconds: offset_in_seconds
                     }
                   }
                 } = smrt_ingestion_from_andi_ingestion.schema |> hd()
        end,
        10,
        200
      )
    end

    test "generates provision for dates", %{
      conn: conn,
      andi_ingestion_with_date: andi_ingestion_with_date
    } do
      schema_field_id = andi_ingestion_with_date.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_ingestion_with_date.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      format = "{YYYY}-{0M}-{0D}"
      offset_in_days = -1

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion_with_date.id,
            "default_offset" => offset_in_days,
            "use_default" => "true",
            "format" => format,
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id
          }
        }
      }

      data_dictionary_view
      |> render_change("validate", %{"data_dictionary_form_schema" => form_schema})

      render_change(view, "save")

      eventually(
        fn ->
          updated_andi_ingestion = Ingestions.get(andi_ingestion_with_date.id)

          smrt_ingestion_from_andi_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(updated_andi_ingestion)

          assert %{
                   default: %{
                     provider: "date",
                     version: "1",
                     opts: %{
                       format: format,
                       offset_in_days: offset_in_days
                     }
                   }
                 } = smrt_ingestion_from_andi_ingestion.schema |> hd()
        end,
        10,
        200
      )
    end

    test "defaults offset to 0", %{conn: conn, andi_ingestion_with_date: andi_ingestion_with_date} do
      schema_field_id = andi_ingestion_with_date.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_ingestion_with_date.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      format = "{YYYY}-{0M}-{0D}"

      form_schema = %{
        "schema" => %{
          "0" => %{
            "ingestion_id" => andi_ingestion_with_date.id,
            "default_offset" => nil,
            "use_default" => "true",
            "format" => format,
            "name" => "date_field",
            "type" => "date",
            "bread_crumb" => "date_field",
            "id" => schema_field_id
          }
        }
      }

      data_dictionary_view
      |> render_change("validate", %{"data_dictionary_form_schema" => form_schema})

      render_change(view, "save")

      eventually(
        fn ->
          updated_andi_ingestion = Ingestions.get(andi_ingestion_with_date.id)

          smrt_ingestion_from_andi_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(updated_andi_ingestion)

          assert %{
                   default: %{
                     provider: "date",
                     version: "1",
                     opts: %{
                       format: format,
                       offset_in_days: 0
                     }
                   }
                 } = smrt_ingestion_from_andi_ingestion.schema |> hd()
        end,
        10,
        200
      )
    end
  end

  defp create_ingestion_with_schema(schema) do
    dataset = TDG.create_dataset(%{})
    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id, schema: schema})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    Ingestions.get(ingestion.id)
  end
end
