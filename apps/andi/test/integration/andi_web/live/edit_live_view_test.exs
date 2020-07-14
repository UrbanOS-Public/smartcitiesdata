defmodule AndiWeb.EditLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.ConnCase
  use Placebo
  import Checkov

  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore
  alias Andi.Services.UrlTest

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [dataset_update: 0, organization_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
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
  alias Andi.InputSchemas.FormTools
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "updating source params" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            sourceQueryParams: %{foo: "bar", baz: "biz"},
            sourceHeaders: %{fool: "barl", bazl: "bizl"}
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)

      %{dataset: andi_dataset}
    end

    data_test "new key/value inputs are added when add button is pressed for #{field}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      html = render_click(view, "add", %{"field" => Atom.to_string(field)})

      assert html |> find_elements(key_class) |> length() == 3
      assert html |> find_elements(value_class) |> length() == 3

      where(
        field: [:sourceQueryParams, :sourceHeaders],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "key/value inputs are deleted when delete button is pressed for #{field}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      btn_id =
        get_attributes(html, btn_class, "phx-value-id")
        |> hd()

      html = render_click(view, "remove", %{"id" => btn_id, "field" => Atom.to_string(field)})

      [key_input] = html |> get_attributes(key_class, "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(value_class, "class")
      refute btn_id =~ value_input

      where(
        field: [:sourceQueryParams, :sourceHeaders],
        btn_class: [".url-form__source-query-params-delete-btn", ".url-form__source-headers-delete-btn"],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "does not have key/value inputs when dataset has no source #{field}", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{field => %{}}})
      {:ok, _andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(key_class) |> Enum.empty?()
      assert html |> find_elements(value_class) |> Enum.empty?()

      where(
        field: [:sourceQueryParams, :sourceHeaders],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    test "source url is updated when source query params are removed", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click(view, "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:sourceQueryParams)
        })
      end)

      url_with_no_query_params = Andi.URI.clear_query_params(dataset.technical.sourceUrl)

      assert render(view) |> get_values(".url-form__source-url input") == [url_with_no_query_params]
    end

    test "source query params added by source url updates can be removed", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      source_url_on_page = get_value(html, ".url-form__source-url input")
      updated_source_url = source_url_on_page <> "&knuckles=true"

      html =
        render_change(view, :validate, %{
          "form_data" => %{"id" => dataset.id, "technical" => %{"id" => dataset.technical.id, "sourceUrl" => updated_source_url}},
          "_target" => ["form_data", "technical", "sourceUrl"]
        })

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 3

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click(view, "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:sourceQueryParams)
        })
      end)

      url_with_no_query_params = Andi.URI.clear_query_params(dataset.technical.sourceUrl)

      assert render(view) |> get_value(".url-form__source-url input") == url_with_no_query_params
    end
  end

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

      assert Enum.empty?(find_elements(html, "input[type='hidden']#form_data_technical_schema_0_description"))
      assert Enum.count(find_elements(html, "input[type='hidden']#form_data_technical_schema_1_description")) > 0
    end

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

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      html = render_click(view, "add_data_dictionary_field", %{})

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

      render_submit([view, "data_dictionary_add_field_editor"], "add_field", form_data)

      html = render(view)

      assert "Natty" == get_text(html, "#data_dictionary_tree_one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "adds field as part of top level schema", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      html = render_click(view, "add_data_dictionary_field", %{})

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

      render_submit([view, "data_dictionary_add_field_editor"], "add_field", form_data)

      html = render(view)

      assert "Steeeeeeez" ==
               get_text(html, "#data_dictionary_tree .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))
    end

    test "dictionary fields with changed types are eligible for adding a field to", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:technical, :schema, Access.at(0), :subSchema, Access.at(0), :type], "map")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data})

      html = render_click(view, "add_data_dictionary_field", %{})

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

      render_submit([view, "data_dictionary_add_field_editor"], "add_field", add_field_form_data)

      html = render(view)

      assert "Jared" ==
               get_text(html, "#data_dictionary_tree_one_one-one .data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "cancels back to modal not being visible", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, ".data-dictionary-add-field-editor--visible"))

      render_click(view, "add_data_dictionary_field", %{})

      render_click([view, "data_dictionary_add_field_editor"], "cancel", %{})

      html = render(view)

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
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      html = render_click(view, "remove_data_dictionary_field", %{})
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(view)
      selected_field_name = "one"

      refute selected_field_name in get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name")
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "removing a field selects the next sibling", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      assert "one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(view)

      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")
    end

    test "removes parent field along with its children", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], &List.delete_at(&1, 0))
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(view, "remove_data_dictionary_field", %{})
      html = render(view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "two" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "true"})
      html = render(view)

      assert "WARNING! Removing this field will also remove its children. Would you like to continue?" ==
               get_text(html, ".data-dicitionary-remove-field-editor__message")

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "no field is selected when the schema is empty", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], &List.delete_at(&1, 1))
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(view, "remove_data_dictionary_field", %{})
      html = render(view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert "one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(view)

      assert Enum.empty?(get_texts(html, ".data-dictionary-tree__field .data-dictionary-tree-field__name"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "no field is selected when subschema is empty", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      child_target = get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-target") |> List.last()
      child_id = get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-value-field-id") |> List.last()

      render_click([view, child_target], "toggle_selected", %{
        "field-id" => child_id,
        "index" => nil,
        "name" => nil,
        "id" => nil
      })

      html = render(view)

      assert "two-one" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(view)

      assert "" == get_text(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__name")

      html = render_click(view, "remove_data_dictionary_field", %{})
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "cannot remove field when none is selected", %{conn: conn, dataset: dataset} do
      dataset
      |> update_in([:technical, :schema], fn _ -> [] end)
      |> Datasets.update()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      assert Enum.empty?(find_elements(html, ".data-dictionary-tree__field--selected"))

      render_click(view, "remove_data_dictionary_field", %{})
      html = render(view)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
    end

    test "shows error message when ecto delete fails", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))

      render_click(view, "remove_data_dictionary_field", %{})
      html = render(view)
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--hidden"))

      [selected_field_id] =
        get_attributes(html, ".data-dictionary-tree__field--selected .data-dictionary-tree-field__text", "phx-value-field-id")

      assert {:ok, _} = DataDictionaryFields.remove_field(selected_field_id)

      render_click([view, "data_dictionary_remove_field_editor"], "remove_field", %{"parent" => "false"})
      html = render(view)

      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor--visible"))
      refute Enum.empty?(find_elements(html, ".data-dictionary-remove-field-editor__error-msg--visible"))
    end
  end

  describe "finalize form" do
    setup do
      dataset = TDG.create_dataset(%{technical: %{cadence: "1 1 1 * * *"}})

      {:ok, andi_dataset} = Datasets.update(dataset)
      [dataset: andi_dataset]
    end

    data_test "quick schedule #{schedule}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_click([view, "finalize_form"], "quick_schedule", %{"schedule" => schedule})
      html = render(view)

      assert expected_crontab == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where([
        [:schedule, :expected_crontab],
        ["hourly", "0 0 * * * *"],
        ["daily", "0 0 0 * * *"],
        ["weekly", "0 0 0 * * 0"],
        ["monthly", "0 0 0 1 * *"],
        ["yearly", "0 0 0 1 1 *"]
      ])
    end

    test "set schedule manually", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      render_change(view, :save, %{"form_data" => form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles five-character cronstrings", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "4 2 7 * *"}})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(andi_dataset)
      render_change(view, :save, %{"form_data" => form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles cadence of never", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "never"}})
      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end
  end

  describe "dataset finalizing buttons" do
    test "allows saving invalid form as draft", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(andi_dataset) |> put_in([:business, :dataTitle], "")
      form_data_changeset = InputConverter.form_data_to_full_changeset(%Dataset{}, form_data)

      render_change(view, :validate, %{"form_data" => form_data})
      html = render_change(view, :save, %{"form_data" => form_data})

      refute form_data_changeset.valid?
      assert Datasets.get(dataset.id) |> get_in([:business, :dataTitle]) == ""
      assert get_text(html, "#form_data_business_dataTitle") == ""
      refute Enum.empty?(find_elements(html, "#dataTitle-error-msg"))
    end

    test "does not reorder schema fields unless the sequence field is specifically set", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      schema = andi_dataset.technical.schema |> Enum.map(fn
        %{name: "my_date"} = field -> Map.put(field, :description, "desc") |> IO.inspect()
        %{name: "my_int"} = field -> Map.put(field, :sequence, "100000") |> IO.inspect()
        %{name: "my_string"} = field -> Map.delete(field, :sequence) |> IO.inspect()
        field -> field
      end)

      updated_dataset = put_in(andi_dataset, [:technical, :schema], schema)
      {:ok, manually_updated_dataset} = Datasets.update(updated_dataset)
      original_schema_order = dataset.technical.schema |> Enum.map(fn %{name: name} -> name end) |> Enum.join(",")

      form_data = FormTools.form_data_from_andi_dataset(updated_dataset) |> put_in([:business, :dataTitle], "")
      form_data_changeset = InputConverter.form_data_to_full_changeset(%Dataset{}, form_data)

      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :save, %{"form_data" => form_data})

      changed_dataset = Datasets.get(dataset.id)
      changed_schema_order = changed_dataset |> get_in([:technical, :schema]) |> Enum.map(fn %{name: name} -> name end) |> Enum.join(",")

      assert changed_dataset |> get_in([:business, :dataTitle]) == ""
      assert "my_string,my_date,my_float,my_boolean,my_int" == changed_schema_order
    end
  end

  describe "create new dataset" do
    setup do
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
      [blank_dataset: blank_dataset]
    end

    test "generate dataName from data title", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], "simpledatatitle")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})

      html = render(view)

      value = get_value(html, "#form_data_technical_dataName")

      assert value == "simpledatatitle"
    end

    test "validation is only triggered for new datasets", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{dataName: "original name"}})

      Brook.Event.send(instance_name(), dataset_update(), __MODULE__, smrt_dataset)

      eventually(
        fn ->
          assert {:ok, nil} != DatasetStore.get(smrt_dataset.id)
        end,
        1_000,
        30
      )

      assert {:ok, view, html} = live(conn, @url_path <> smrt_dataset.id)

      dataset = Datasets.get(smrt_dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], "simpledatatitle")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})

      html = render(view)

      value = get_value(html, "#form_data_technical_dataName")

      assert value == "original name"
    end

    data_test "data title #{title} generates data name #{data_name}", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], title)
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})
      html = render(view)

      assert get_value(html, "#form_data_technical_dataName") == data_name

      where([
        [:title, :data_name],
        ["title with spaces", "title_with_spaces"],
        ["titl3! W@th sp#ci@l ch@rs", "titl3_wth_spcil_chrs"],
        ["ALL CAPS TITLE", "all_caps_title"]
      ])
    end

    data_test "#{title} generating an empty data name is invalid", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], title)
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})
      html = render(view)

      assert get_value(html, "#form_data_technical_dataName") == ""
      refute Enum.empty?(find_elements(html, "#dataName-error-msg"))

      where(title: ["", "!@#$%"])
    end

    test "organization dropdown is populated with all organizations in the system", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      org1 = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title", id: "95254592-d611-4bcb-9478-7fa248f4118d"})
      org2 = TDG.create_organization(%{orgTitle: "Very Readable", orgName: "very_readable", id: "95254592-4444-4bcb-9478-7fa248f4118d"})

      Brook.Event.send(instance_name(), organization_update(), __MODULE__, org1)
      Brook.Event.send(instance_name(), organization_update(), __MODULE__, org2)

      eventually(fn ->
        assert OrgStore.get(org1.id) != {:ok, nil}
        assert OrgStore.get(org2.id) != {:ok, nil}
      end)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert {"", ["Please select an organization"]} == get_select_first_option(html, "#form_data_technical_orgId")

      form_data =
        dataset
        |> put_in([:technical, :dataName], "data_title")
        |> put_in([:technical, :orgId], "95254592-4444-4bcb-9478-7fa248f4118d")
        |> FormTools.form_data_from_andi_dataset()

      html = render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "technical", "orgId"]})

      assert "very_readable__data_title" == get_value(html, "#form_data_technical_systemName")
      assert {"95254592-4444-4bcb-9478-7fa248f4118d", "Very Readable"} == get_select(html, "#form_data_technical_orgId")
    end

    test "updating data title allows common data name across different orgs", %{conn: conn} do
      existing_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "camido", systemName: "kevino__camino"}})
      {:ok, _} = Datasets.update(existing_dataset)

      new_dataset = TDG.create_dataset(%{technical: %{orgName: "carrabino", dataName: "blah", systemName: "carrabino__blah"}})
      {:ok, new_andi_dataset} = Datasets.update(new_dataset)

      assert {:ok, view, _} = live(conn, @url_path <> new_dataset.id)

      form_data =
        new_andi_dataset
        |> put_in([:business, :dataTitle], "camido")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})
      render(view)
      render_change(view, "validate_system_name", nil)
      html = render(view)

      assert Enum.empty?(find_elements(html, "#dataName-error-msg"))
    end

    test "updating data title adds error when data name exists within same org", %{conn: conn} do
      existing_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "camino", systemName: "kevino__camino"}})
      {:ok, _} = Datasets.update(existing_dataset)

      new_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "harharhar", systemName: "kevino__harharhar"}})
      {:ok, new_andi_dataset} = Datasets.update(new_dataset)

      assert {:ok, view, _} = live(conn, @url_path <> new_dataset.id)

      form_data =
        new_andi_dataset
        |> put_in([:business, :dataTitle], "camino")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})
      render(view)
      render_change(view, "validate_system_name", nil)
      html = render(view)

      refute Enum.empty?(find_elements(html, "#dataName-error-msg"))
    end

    test "changing org retriggers data_name validation", %{conn: conn} do
      existing_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "camino", systemName: "kevino__camino"}})
      {:ok, _} = Datasets.update(existing_dataset)

      new_dataset = TDG.create_dataset(%{technical: %{orgName: "benjino", dataName: "camino", systemName: "benjino__camino"}})
      {:ok, new_andi_dataset} = Datasets.update(new_dataset)

      org = TDG.create_organization(%{id: "1", orgTitle: "kevin org", orgName: "kevino"})

      Brook.Event.send(:andi, organization_update(), __MODULE__, org)

      eventually(fn -> OrgStore.get(org.id) != {:ok, nil} end)

      assert {:ok, view, _} = live(conn, @url_path <> new_dataset.id)

      form_data =
        new_andi_dataset
        |> put_in([:business, :dataTitle], "camino")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "business", "dataTitle"]})
      render(view)
      render_change(view, "validate_system_name", nil)
      html = render(view)

      assert Enum.empty?(find_elements(html, "#dataName-error-msg"))

      form_data =
        new_andi_dataset
        |> put_in([:technical, :orgId], "1")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "technical", "orgId"]})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#dataName-error-msg"))
    end
  end

  describe "enter form data" do
    test "display Level of Access as public when private is false", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{private: false}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"false", "Public"} = get_select(html, ".metadata-form__level-of-access")
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{private: true}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"true", "Private"} = get_select(html, ".metadata-form__level-of-access")
    end

    test "the default language is set to english", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, ".metadata-form__language")
    end

    test "the language is set to spanish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{language: "spanish"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    test "the language is changed from english to spanish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :language], "spanish")

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    data_test "benefit rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{benefitRating: value}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, ".metadata-form__benefit-rating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "risk rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{riskRating: value}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, ".metadata-form__risk-rating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "errors on invalid email: #{email}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{contactEmail: email}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#contactEmail-error-msg") == "Please enter a valid maintainer email."

      where([
        [:email],
        ["foomail.com"],
        ["kevinspace@"],
        ["kevinspace@notarealdomain"],
        ["my little address"]
      ])
    end

    data_test "does not error on valid email: #{email}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{contactEmail: email}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#contactEmail-error-msg") == ""

      where([
        [:email],
        ["foo@mail.com"],
        ["kevin@space.org"],
        ["my@little.gov"],
        ["test-email@email.com"]
      ])
    end

    test "adds commas between keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject =~ "one, two, three"
    end

    test "keywords input should show empty string if keywords is nil", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{keywords: nil}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject == ""
    end

    test "should not add additional commas to keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :keywords], Enum.join(dataset.business.keywords, ", "))

      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")

      assert expected == subject
    end

    test "should trim spaces in keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :keywords], "a , good ,  keyword   , is .... hard , to find")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      expected = Enum.join(dataset.business.keywords, ", ")

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :keywords], expected)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")

      assert expected == subject
    end

    test "displays all other fields", %{conn: conn} do
      org = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title", id: "95254592-d611-4bcb-9478-7fa248f4118d"})
      Brook.Event.send(instance_name(), organization_update(), __MODULE__, org)
      eventually(fn -> OrgStore.get(org.id) != {:ok, nil} end)

      smrt_dataset =
        TDG.create_dataset(%{
          business: %{
            description: "A description with no special characters",
            benefitRating: 1.0,
            riskRating: 0.5
          },
          technical: %{private: true, orgId: org.id}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert get_value(html, ".metadata-form__title input") == dataset.business.dataTitle
      assert get_text(html, ".metadata-form__description textarea") == dataset.business.description
      {selected_format, _} = get_select(html, ".metadata-form__format select")
      assert selected_format == dataset.technical.sourceFormat
      assert {"true", "Private"} == get_select(html, ".metadata-form__level-of-access")
      assert get_value(html, ".metadata-form__maintainer-name input") == dataset.business.contactName
      assert dataset.business.modifiedDate |> Date.to_string() =~ get_value(html, ".metadata-form__last-updated input")
      assert get_value(html, ".metadata-form__maintainer-email input") == dataset.business.contactEmail
      assert dataset.business.issuedDate |> Date.to_string() =~ get_value(html, ".metadata-form__release-date input")
      assert get_value(html, ".metadata-form__license input") == dataset.business.license
      assert get_value(html, ".metadata-form__update-frequency input") == dataset.business.publishFrequency
      assert get_value(html, ".metadata-form__spatial input") == dataset.business.spatial
      assert get_value(html, ".metadata-form__temporal input") == dataset.business.temporal

      assert {"95254592-d611-4bcb-9478-7fa248f4118d", "Awesome Title"} == get_select(html, ".metadata-form__organization select")

      assert {"english", "English"} == get_select(html, ".metadata-form__language")
      assert get_value(html, ".metadata-form__homepage input") == dataset.business.homepage
      assert {"1.0", "High"} == get_select(html, ".metadata-form__benefit-rating")
      assert {"0.5", "Medium"} == get_select(html, ".metadata-form__risk-rating")
    end
  end

  describe "edit form data" do
    test "accessibility level must be public or private", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{private: true}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_select(html, ".metadata-form__level-of-access") == {"true", "Private"}

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :private], false)

      html = render_change(view, :validate, %{"form_data" => form_data})
      assert get_select(html, ".metadata-form__level-of-access") == {"false", "Public"}
    end

    data_test "required #{field} field displays proper error message", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(dataset_override)

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :dataset_override, :expected_error_message],
        [:dataTitle, %{business: %{dataTitle: ""}}, "Please enter a valid dataset title."],
        [:description, %{business: %{description: ""}}, "Please enter a valid description."],
        [:contactName, %{business: %{contactName: ""}}, "Please enter a valid maintainer name."],
        [:contactEmail, %{business: %{contactEmail: ""}}, "Please enter a valid maintainer email."],
        [:issuedDate, %{business: %{issuedDate: nil}}, "Please enter a valid release date."],
        [:license, %{business: %{license: ""}}, "Please enter a valid license."],
        [:publishFrequency, %{business: %{publishFrequency: ""}}, "Please enter a valid update frequency."],
        [:orgTitle, %{business: %{orgTitle: ""}}, "Please enter a valid organization."],
        [:sourceUrl, %{technical: %{sourceUrl: ""}}, "Please enter a valid base url."],
        [:license, %{business: %{license: ""}}, "Please enter a valid license."],
        [:benefitRating, %{business: %{benefitRating: nil}}, "Please enter a valid benefit."],
        [:riskRating, %{business: %{riskRating: nil}}, "Please enter a valid risk."],
        [:topLevelSelector, %{technical: %{sourceFormat: "text/xml", topLevelSelector: ""}}, "Please enter a valid top level selector."]
      ])
    end

    test "required sourceFormat displays proper error message", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :sourceFormat], "")

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#sourceFormat-error-msg") == "Please enter a valid source format."
    end

    test "source format before publish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(get_attributes(html, ".metadata-form__format select", "disabled"))
    end

    data_test "invalid #{field} displays proper error message", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{field => %{"foo" => "where's my key"}}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, field], %{"0" => %{"key" => "", "value" => "where's my key"}})

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == "Please enter valid key(s)."

      where(field: [:sourceQueryParams, :sourceHeaders])
    end

    data_test "displays error when #{field} is unset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "##{field}-error-msg") == ""

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, field], "")

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :expected_error_message],
        [:benefitRating, "Please enter a valid benefit."],
        [:riskRating, "Please enter a valid risk."]
      ])
    end

    test "error message is cleared when form is updated", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#issuedDate-error-msg") == "Please enter a valid release date."

      updated_form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      html = render_change(view, :validate, %{"form_data" => updated_form_data})

      assert get_text(html, "#issuedDate-error-msg") == ""
    end

    test "displays error when topLevelSelector jpath is invalid", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceFormat: "application/json", topLevelSelector: "$.data[x]"}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#topLevelSelector-error-msg") == "Error: Expected an integer at `x]`"
    end

    test "topLevelSelector is read only when sourceFormat is not xml nor json", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      refute Enum.empty?(get_attributes(html, "#form_data_technical_topLevelSelector", "readonly"))
    end
  end

  describe "can not edit" do
    test "source format", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      Brook.Event.send(instance_name(), dataset_update(), __MODULE__, smrt_dataset)
      eventually(fn -> DatasetStore.get(smrt_dataset.id) != {:ok, nil} end)

      assert {:ok, view, html} = live(conn, @url_path <> smrt_dataset.id)

      refute Enum.empty?(get_attributes(html, ".metadata-form__format select", "disabled"))
    end

    test "organization title", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      Brook.Event.send(instance_name(), dataset_update(), __MODULE__, smrt_dataset)
      eventually(fn -> DatasetStore.get(smrt_dataset.id) != {:ok, nil} end)

      org = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title", id: "95254592-d611-4bcb-9478-7fa248f4118d"})
      Brook.Event.send(instance_name(), organization_update(), __MODULE__, org)
      eventually(fn -> OrgStore.get(org.id) != {:ok, nil} end)

      assert {:ok, view, html} = live(conn, @url_path <> smrt_dataset.id)

      assert get_attributes(html, ".metadata-form__organization select", "disabled")
    end
  end

  describe "hidden so form_data has all the validated fields in it" do
    data_test "#{name} is hidden", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, "#form_data_technical_#{name}", "type") == ["hidden"]

      where([
        [:name],
        ["orgName"],
        ["sourceType"]
      ])
    end
  end

  describe "save and publish form data" do
    test "valid form data is saved on publish", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{modifiedDate: "2020-01-04T01:02:03Z"}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      dataset = Datasets.get(dataset.id)
      {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)

      eventually(fn ->
        assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
      end)
    end

    test "invalid form data is not saved on publish", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{publishFrequency: "I dunno, whenever, I guess"}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :publishFrequency], "")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      eventually(fn ->
        assert %{business: %{publishFrequency: "I dunno, whenever, I guess"}} = Datasets.get(dataset.id)
      end)
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#snackbar") == ""

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :issuedDate], "2020-01-03")

      html = render_change(view, :save, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, "#snackbar.success-message"))
      assert get_text(html, "#snackbar") != ""
    end

    test "saving form as draft does not send brook event", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      render_change(view, :save, %{"form_data" => form_data})

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "saving form as draft with invalid changes warns user", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{dataTitle: ""}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)

      form_data = FormTools.form_data_from_andi_dataset(dataset)

      html = render_change(view, :save, %{"form_data" => form_data})

      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "allows clearing modified date", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{modifiedDate: "2020-01-01T00:00:00Z"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:business, :modifiedDate], nil)

      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      eventually(fn ->
        assert {:ok, nil} != DatasetStore.get(dataset.id)
      end)
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, other_dataset} = Datasets.update(TDG.create_dataset(%{}))

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :dataName], other_dataset.technical.dataName)
        |> put_in([:technical, :orgName], other_dataset.technical.orgName)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :validate_system_name)
      render_change(view, :publish)

      assert render(view) |> get_text("#snackbar") =~ "errors"
    end

    data_test "allows saving with empty #{field}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{field => %{"x" => "y"}}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> Map.update!(:technical, &Map.delete(&1, field))

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      dataset = Datasets.get(dataset.id)
      {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)

      eventually(fn ->
        assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
      end)

      where(field: [:sourceQueryParams, :sourceHeaders])
    end

    test "alert shows when section changes are unsaved on cancel action", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], "a new datset title")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data})

      refute [] == find_elements(html, ".unsaved-changes-modal--hidden")

      render_change(view, "cancel-edit", %{})

      html = render(view)

      refute [] == find_elements(html, ".unsaved-changes-modal--visible")
    end

    test "clicking continues takes you back to the datasets page without saved changes", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> put_in([:business, :dataTitle], "a new datset title")
        |> FormTools.form_data_from_andi_dataset()

      render_change(view, "validate", %{"form_data" => form_data})

      render_change(view, "cancel-edit", %{})

      html = render(view)

      refute [] == find_elements(html, ".unsaved-changes-modal--visible")

      render_change(view, "force-cancel-edit", %{})

      assert_redirect(view, "/")
    end
  end

  describe "sourceUrl testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            sourceUrl: "123.com",
            sourceQueryParams: %{"x" => "y"},
            sourceHeaders: %{"api-key" => "to-my-heart"}
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :test_url, %{})

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))
    end

    data_test "sourceQueryParams are updated when query params are added to source url", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :sourceUrl], sourceUrl)

      html =
        render_change(view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "technical", "sourceUrl"]
        })

      assert get_values(html, ".url-form__source-query-params-key-input") == keys
      assert get_values(html, ".url-form__source-query-params-value-input") == values

      where([
        [:sourceUrl, :keys, :values],
        ["http://example.com?cat=dog", ["cat"], ["dog"]],
        ["http://example.com?cat=dog&foo=bar", ["cat", "foo"], ["dog", "bar"]],
        ["http://example.com?cat=dog&foo+biz=bar", ["cat", "foo biz"], ["dog", "bar"]],
        ["http://example.com?cat=", ["cat"], [""]],
        ["http://example.com?=dog", [""], ["dog"]]
      ])
    end

    data_test "sourceUrl is updated when query params are added", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        FormTools.form_data_from_andi_dataset(dataset)
        |> put_in([:technical, :sourceUrl], intialSourceUrl)
        |> put_in([:technical, :sourceQueryParams], queryParams)

      html =
        render_change(view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "technical", "sourceQueryParams"]
        })

      assert get_values(html, ".url-form__source-url input") == [updatedSourceUrl]

      where([
        [:intialSourceUrl, :queryParams, :updatedSourceUrl],
        [
          "http://example.com",
          %{"0" => %{"key" => "dog", "value" => "car"}, "1" => %{"key" => "new", "value" => "thing"}},
          "http://example.com?dog=car&new=thing"
        ],
        ["http://example.com?dog=cat&fish=water", %{"0" => %{"key" => "dog", "value" => "cat"}}, "http://example.com?dog=cat"],
        ["http://example.com?dog=cat&fish=water", %{}, "http://example.com"],
        [
          "http://example.com?dog=cat",
          %{"0" => %{"key" => "some space", "value" => "thing=whoa"}},
          "http://example.com?some+space=thing%3Dwhoa"
        ]
      ])
    end

    test "status and time are displayed when source url is tested", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceUrl: "123.com"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code") == "200"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code--good") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code--good") == "200"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 400})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code--bad") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code--bad") == "400"
        assert get_text(html, ".test-status__code--good") != "400"
      end)
    end

    @tag capture_log: true
    test "status is displayed with an appropriate class when an internal page error occurred", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), exec: fn _ -> raise "derp" end)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#snackbar") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, "#snackbar") == "A page error occurred"
      end)
    end
  end

  defp get_crontab_from_html(html) do
    html
    |> get_values(".finalize-form-schedule-input__field")
    |> Enum.join(" ")
    |> String.trim_leading()
  end
end
