defmodule AndiWeb.DataDictionaryFormTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov
  import SmartCity.TestHelper, only: [eventually: 3]

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
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.Helpers.FormTools

  @endpoint AndiWeb.Endpoint
  @url_path "/submissions/"

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

    test "generates hidden inputs for fields that are not selected", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
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
          }
        })

      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, "input[type='hidden']#data_dictionary_form_schema_schema_0_description"))
      assert Enum.count(find_elements(html, "input[type='hidden']#data_dictionary_form_schema_schema_1_description")) > 0
    end

    test "handles datasets with no schema fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}}) |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "displays help for datasets with empty schema fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceType: "ingest", schema: []}})

      dataset
      |> InputConverter.smrt_dataset_to_draft_changeset()
      |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_text(html, ".data-dictionary-tree__getting-started-help") =~ "add a new field"
    end

    test "does not display help for datasets with empty subschema fields", %{conn: conn} do
      field_with_empty_subschema = %{name: "max", type: "map", subSchema: []}
      dataset = TDG.create_dataset(%{technical: %{sourceType: "ingest", schema: [field_with_empty_subschema]}})

      dataset
      |> InputConverter.smrt_dataset_to_draft_changeset()
      |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      refute get_text(html, ".data-dictionary-tree__getting-started-help") =~ "add a new field"
    end
  end

  describe "schema sample upload" do
    test "is shown when sourceFormat is CSV or JSON", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "application/json"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")
      html = render(data_dictionary_view)

      refute Enum.empty?(find_elements(html, ".data-dictionary-form__file-upload"))
    end

    test "is hidden when sourceFormat is not CSV nor JSON", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "application/geo+json"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")
      html = render(data_dictionary_view)

      assert Enum.empty?(find_elements(html, ".data-dictionary-form__file-upload"))
    end

    test "does not allow file uploads greater than 200MB", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 200_000_001})

      refute Enum.empty?(find_elements(html, "#schema_sample-error-msg"))
    end

    test "should throw error when empty csv file is passed", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample = ""

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      refute Enum.empty?(find_elements(html, "#schema_sample-error-msg"))
    end

    data_test "accepts common csv file type #{type}", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample = "string,int,float,bool,date\nabc,9,1.5,true,2020-07-22T21:24:40"

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 10, "fileType" => type, "file" => csv_sample})

      assert Enum.empty?(find_elements(html, "#schema_sample-error-msg"))

      where([
        [:type],
        ["text/csv"],
        ["application/vnd.ms-excel"]
      ])
    end

    test "should throw error when empty csv file with `\n` is passed", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample = "\n"

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      refute Enum.empty?(find_elements(html, "#schema_sample-error-msg"))
    end

    test "provides modal when existing schema will be overwritten", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample = "CAM\nrules"

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      refute Enum.empty?(find_elements(html, ".overwrite-schema-modal--visible"))
    end

    test "does not provide modal with no existing schema", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{technical: %{sourceType: "remote", sourceFormat: "text/csv"}})
        |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample = "CAM\nrules"

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      assert Enum.empty?(find_elements(html, ".overwrite-schema-modal--visible"))

      updated_dataset = Datasets.get(dataset.id)
      refute Enum.empty?(updated_dataset.technical.schema)
    end

    test "parses CSVs with various types", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{technical: %{sourceType: "remote", sourceFormat: "text/csv"}})
        |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample = "string,int,float,bool,date,timestamp\nabc,9,1.5,true,2020-07-22,2020-07-22T21:24:40"

      render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      updated_dataset = Datasets.get(dataset.id)

      generated_schema =
        updated_dataset.technical.schema
        |> Enum.map(fn item -> %{type: item.type, name: item.name} end)

      expected_schema = [
        %{name: "string", type: "string"},
        %{name: "int", type: "integer"},
        %{name: "float", type: "float"},
        %{name: "bool", type: "boolean"},
        %{name: "date", type: "date"},
        %{name: "timestamp", type: "timestamp"}
      ]

      assert generated_schema == expected_schema
    end

    test "parses CSV with valid column names", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{technical: %{sourceType: "remote", sourceFormat: "text/csv"}})
        |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      csv_sample =
        "string\r,i&^%$nt,fl\toat,bool---,date as multi word column,timestamp as multi word column\nabc,9,1.5,true,2020-07-22,2020-07-22T21:24:40"

      render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "text/csv", "file" => csv_sample})

      updated_dataset = Datasets.get(dataset.id)

      generated_schema =
        updated_dataset.technical.schema
        |> Enum.map(fn item -> %{type: item.type, name: item.name} end)

      expected_schema = [
        %{name: "string", type: "string"},
        %{name: "int", type: "integer"},
        %{name: "float", type: "float"},
        %{name: "bool", type: "boolean"},
        %{name: "date as multi word column", type: "date"},
        %{name: "timestamp as multi word column", type: "timestamp"}
      ]

      assert generated_schema == expected_schema
    end

    test "handles invalid json", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{technical: %{sourceType: "remote", sourceFormat: "application/json"}})
        |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      json_sample =
        "header {\n  gtfs_realtime_version: \"2.0\"\n  incrementality: FULL_DATASET\n  timestamp: 1582913296\n}\nentity {\n  id: \"2551\"\n  vehicle {\n    trip {\n      trip_id: \"2290874_MRG_1\"\n      start_date: \"20200228\"\n      route_id: \"661\"\n    }\n"

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "application/json", "file" => json_sample})

      refute Enum.empty?(find_elements(html, "#schema_sample-error-msg"))
    end

    test "should throw error when empty json file is passed", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{technical: %{sourceType: "remote", sourceFormat: "application/json"}})
        |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      json_sample = "[]"

      html = render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "application/json", "file" => json_sample})
      refute Enum.empty?(find_elements(html, "#schema_sample-error-msg"))
    end

    test "generates eligible parents list", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{technical: %{sourceType: "remote", sourceFormat: "application/json"}})
        |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      {:ok, _} = Datasets.update(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      json_sample = [%{list_field: [%{child_list_field: []}]}] |> Jason.encode!()

      render_hook(data_dictionary_view, "file_upload", %{"fileSize" => 100, "fileType" => "application/json", "file" => json_sample})

      updated_dataset = Datasets.get(dataset.id)

      generated_bread_crumbs =
        updated_dataset
        |> DataDictionaryFields.get_parent_ids()
        |> Enum.map(fn {bread_crumb, _} -> bread_crumb end)

      assert ["Top Level", "list_field", "list_field > child_list_field"] == generated_bread_crumbs
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
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

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

      form = element(data_dictionary_view, "#data_dictionary_add_field_editor form")
      add_button = element(data_dictionary_view, "#data_dictionary_add_field_editor button", "ADD FIELD")

      render_change(form, form_data)
      render(data_dictionary_view)
      render_click(add_button)
      html = render(data_dictionary_view)

      assert "Natty" == get_text(html, "#data_dictionary_tree_one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "adds field as part of top level schema", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

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

      form = element(data_dictionary_view, "#data_dictionary_add_field_editor form")
      add_button = element(data_dictionary_view, "#data_dictionary_add_field_editor button", "ADD FIELD")

      render_change(form, form_data)
      render(data_dictionary_view)
      render_click(add_button)

      html = render(data_dictionary_view)

      assert "Steeeeeeez" ==
               get_text(html, "#data_dictionary_tree .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "dictionary fields with changed types are eligible for adding a field to", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      updated_dataset_schema =
        dataset
        |> put_in([:technical, :schema, Access.at(0), :subSchema, Access.at(0), :type], "map")
        |> FormTools.form_data_from_andi_dataset()
        |> get_in([:technical, :schema])

      form_data = %{"schema" => updated_dataset_schema}

      render_change(data_dictionary_view, "validate", %{"data_dictionary_form_schema" => form_data})

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
               get_text(html, "#data_dictionary_tree_one_one-one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "cancels back to modal not being visible", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
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
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      html = render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")
      render_click(delete_button)
      html = render(data_dictionary_view)
      selected_field_name = "one"

      refute selected_field_name in get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name")
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "removing a field selects the next sibling", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")
      render_click(delete_button)
      html = render(data_dictionary_view)

      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "removes parent field along with its children", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], &List.delete_at(&1, 0))
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

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

    test "no field is selected when the schema is empty", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], &List.delete_at(&1, 1))
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")
      render_click(delete_button)

      html = render(data_dictionary_view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "no field is selected when subschema is empty", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      child_id = get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-value-field-id") |> List.last()

      selectable = element(data_dictionary_view, ".data-dictionary-tree-field__text[phx-value-field-id='#{child_id}']")
      render_click(selectable)

      html = render(data_dictionary_view)

      assert "two-one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")
      render_click(delete_button)

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
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "shows error message when ecto delete fails", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(data_dictionary_view, "remove_data_dictionary_field", %{})
      html = render(data_dictionary_view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--hidden"))

      [selected_field_id] =
        get_attributes(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__text", "phx-value-field-id")

      assert {:ok, _} = DataDictionaryFields.remove_field(selected_field_id)

      delete_button = element(data_dictionary_view, "#data_dictionary_remove_field_editor button", "DELETE")
      render_click(delete_button)

      html = render(data_dictionary_view)

      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--visible"))
    end
  end

  describe "non curators have a limited view of the data dictionary form" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})
      [public_user: public_user]
    end

    test "users aren't able to access the upload feature for data dictionary in the ssui", %{public_conn: conn, public_user: public_user} do
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{sourceFormat: "application/json"}, business: %{}}

      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

      assert Enum.empty?(find_elements(html, ".data-dictionary-form__file-upload"))
    end
  end

  test "required schema field displays proper error message", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{technical: %{schema: []}})

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

    assert get_text(html, "#schema-error-msg") == "Please add a field to continue"
  end

  describe "default timestamp/date" do
    setup do
      smrt_dataset_with_timestamp = TDG.create_dataset(%{technical: %{schema: [%{name: "timestamp_field", type: "timestamp"}]}})

      smrt_dataset_with_date = TDG.create_dataset(%{technical: %{schema: [%{name: "date_field", type: "date"}]}})

      {:ok, andi_dataset_with_timestamp} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset_with_timestamp)
        |> Datasets.save()

      {:ok, andi_dataset_with_date} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset_with_date)
        |> Datasets.save()

      [andi_dataset_with_date: andi_dataset_with_date, andi_dataset_with_timestamp: andi_dataset_with_timestamp]
    end

    test "replaces provider with nil when use default checkbox is unselected", %{conn: conn} do
      smrt_dataset_with_provider =
        TDG.create_dataset(%{
          technical: %{
            schema: [%{name: "date_field", type: "date", default: %{provider: "date", version: "1", opts: %{offset_in_days: -1}}}]
          }
        })

      {:ok, andi_dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset_with_provider)
        |> Datasets.save()

      schema_field_id = andi_dataset.technical.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert ["checked"] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")
      assert get_value(html, "#data_dictionary_field_editor__offset_input") == "-1"

      form_schema = %{
        "schema" => %{
          "0" => %{
            "dataset_id" => andi_dataset.id,
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

      render_change(view, "save-all-draft")

      eventually(
        fn ->
          updated_andi_ds = Datasets.get(andi_dataset.id)
          {:ok, smrt_ds_from_andi_ds} = InputConverter.andi_dataset_to_smrt_dataset(updated_andi_ds)
          updated_schema_field = smrt_ds_from_andi_ds.technical.schema |> hd()

          refute Map.has_key?(updated_schema_field, :default)
          assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor__use-default", "checked"))
          assert ["disabled"] = get_attributes(html, "#data_dictionary_field_editor__offset_input", "disabled")
        end,
        20,
        200
      )
    end

    test "replaces nil provider with default when use default checkbox is checked", %{conn: conn} do
      smrt_dataset_without_provider = TDG.create_dataset(%{technical: %{schema: [%{name: "date_field", type: "date"}]}})

      {:ok, andi_dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset_without_provider)
        |> Datasets.save()

      schema_field_id = andi_dataset.technical.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor__use-default", "checked"))
      assert ["disabled"] = get_attributes(html, "#data_dictionary_field_editor__offset_input", "disabled")

      form_schema = %{
        "schema" => %{
          "0" => %{
            "dataset_id" => andi_dataset.id,
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

      render_change(view, "save-all-draft")

      eventually(
        fn ->
          updated_andi_ds = Datasets.get(andi_dataset.id)
          {:ok, smrt_ds_from_andi_ds} = InputConverter.andi_dataset_to_smrt_dataset(updated_andi_ds)
          updated_schema_field = smrt_ds_from_andi_ds.technical.schema |> hd()

          assert ["checked"] = get_attributes(html, "#data_dictionary_field_editor__use-default", "checked")
          assert %{provider: "date"} = Map.get(updated_schema_field, :default)
        end,
        20,
        100
      )
    end

    test "generates provision for timestamps", %{conn: conn, andi_dataset_with_timestamp: andi_dataset_with_timestamp} do
      schema_field_id = andi_dataset_with_timestamp.technical.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_dataset_with_timestamp.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      format = "{YYYY}-{0M}-{0D}"
      offset_in_seconds = -1 * 60 * 60 * 24

      form_schema = %{
        "schema" => %{
          "0" => %{
            "dataset_id" => andi_dataset_with_timestamp.id,
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

      render_change(view, "save-all-draft")

      eventually(
        fn ->
          updated_andi_ds = Datasets.get(andi_dataset_with_timestamp.id)
          {:ok, smrt_ds_from_andi_ds} = InputConverter.andi_dataset_to_smrt_dataset(updated_andi_ds)

          assert %{
                   default: %{
                     provider: "timestamp",
                     version: "2",
                     opts: %{
                       format: format,
                       offset_in_seconds: offset_in_seconds
                     }
                   }
                 } = smrt_ds_from_andi_ds.technical.schema |> hd()
        end,
        10,
        200
      )
    end

    test "generates provision for dates", %{conn: conn, andi_dataset_with_date: andi_dataset_with_date} do
      schema_field_id = andi_dataset_with_date.technical.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_dataset_with_date.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      format = "{YYYY}-{0M}-{0D}"
      offset_in_days = -1

      form_schema = %{
        "schema" => %{
          "0" => %{
            "dataset_id" => andi_dataset_with_date.id,
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

      render_change(view, "save-all-draft")

      eventually(
        fn ->
          updated_andi_ds = Datasets.get(andi_dataset_with_date.id)
          {:ok, smrt_ds_from_andi_ds} = InputConverter.andi_dataset_to_smrt_dataset(updated_andi_ds)

          assert %{
                   default: %{
                     provider: "date",
                     version: "1",
                     opts: %{
                       format: format,
                       offset_in_days: offset_in_days
                     }
                   }
                 } = smrt_ds_from_andi_ds.technical.schema |> hd()
        end,
        10,
        200
      )
    end

    test "defaults offset to 0", %{conn: conn, andi_dataset_with_date: andi_dataset_with_date} do
      schema_field_id = andi_dataset_with_date.technical.schema |> hd() |> Map.get(:id)

      {:ok, view, html} = live(conn, @url_path <> andi_dataset_with_date.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      format = "{YYYY}-{0M}-{0D}"

      form_schema = %{
        "schema" => %{
          "0" => %{
            "dataset_id" => andi_dataset_with_date.id,
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

      render_change(view, "save-all-draft")

      eventually(
        fn ->
          updated_andi_ds = Datasets.get(andi_dataset_with_date.id)
          {:ok, smrt_ds_from_andi_ds} = InputConverter.andi_dataset_to_smrt_dataset(updated_andi_ds)

          assert %{
                   default: %{
                     provider: "date",
                     version: "1",
                     opts: %{
                       format: format,
                       offset_in_days: 0
                     }
                   }
                 } = smrt_ds_from_andi_ds.technical.schema |> hd()
        end,
        10,
        200
      )
    end
  end
end
