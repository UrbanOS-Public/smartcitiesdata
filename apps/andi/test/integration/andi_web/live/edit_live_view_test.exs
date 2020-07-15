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
