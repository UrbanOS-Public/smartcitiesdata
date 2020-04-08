defmodule AndiWeb.EditLiveViewTest do
  use ExUnit.Case
  use Divo
  use Andi.DataCase
  use AndiWeb.ConnCase
  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_texts: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets

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

      {:ok, _andi_dataset} = Datasets.update(dataset)

      %{dataset: dataset}
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

      assert render(view) |> get_values(".url-form__source-url input") == [dataset.technical.sourceUrl]
    end

    test "source query params added by source url updates can be removed", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      source_url_on_page = get_value(html, ".url-form__source-url input")
      updated_source_url = source_url_on_page <> "&knuckles=true"

      html =
        render_change(view, :validate, %{
          "form_data" => %{"id" => dataset.id, "technical" => %{"sourceUrl" => updated_source_url}},
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

      assert render(view) |> get_value(".url-form__source-url input") == dataset.technical.sourceUrl
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
                subType: "map",
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
                subType: "map",
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
      dataset = TDG.create_dataset(%{schema: []})

      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end
  end
end
