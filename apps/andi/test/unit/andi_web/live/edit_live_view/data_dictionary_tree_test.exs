defmodule AndiWeb.EditLiveView.DataDictionaryTreeTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_texts: 2,
      get_attributes: 3
    ]

  @url_path "/datasets/"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "expand/collapse and check/uncheck" do
    setup %{conn: conn} do
      dataset =
      TDG.create_dataset(%{
        technical: %{
          schema: [
            %{
              name: "one",
              type: "list",
              subType: "map",
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

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [expandable_one_id, expandable_two_id] = get_attributes(html, ".data-dictionary-tree__field[phx-click='toggle_expanded']", "phx-value-field-id")
      [expandable_one_target, expandable_two_target] = get_attributes(html, ".data-dictionary-tree__field[phx-click='toggle_expanded']", "phx-target")
      [checkable_one_id, checkable_two_id] = get_attributes(html, ".data-dictionary-tree__field[phx-click='toggle_checked']", "phx-value-field-id")
      [checkable_one_target, checkable_two_target] = get_attributes(html, ".data-dictionary-tree__field[phx-click='toggle_checked']", "phx-target")

      [
        view: view,
        html: html,
        expandable_one: %{id: expandable_one_id, target: expandable_one_target},
        expandable_two: %{id: expandable_two_id, target: expandable_two_target},
        checkable_one: %{id: checkable_one_id, target: checkable_one_target},
        checkable_two: %{id: checkable_two_id, target: checkable_two_target}
      ]
    end

    test "initially expandable fields are expanded", %{html: html, expandable_one: expandable_one, expandable_two: expandable_two} do
      one_id = expandable_one.id
      two_id = expandable_two.id

      assert [^one_id, ^two_id] =
        get_attributes(html, ".data-dictionary-tree__field--expanded", "phx-value-field-id")
    end

    test "clicking an expandable field once collapses it", %{view: view, expandable_one: expandable_one}  do
      one_id = expandable_one.id

      html = render_click([view, expandable_one.target], "toggle_expanded", %{"field-id" => expandable_one.id})

      assert [^one_id] =
        get_attributes(html, ".data-dictionary-tree__field--collapsed", "phx-value-field-id")
    end

    test "clicking an expandable field twice toggles it", %{view: view, expandable_one: expandable_one}  do
      one_id = expandable_one.id

      _html = render_click([view, expandable_one.target], "toggle_expanded", %{"field-id" => expandable_one.id})
      html = render_click([view, expandable_one.target], "toggle_expanded", %{"field-id" => expandable_one.id})

      assert [^one_id | _] =
        get_attributes(html, ".data-dictionary-tree__field--expanded", "phx-value-field-id")
    end

    test "clicking an expandable field does not affect another field", %{view: view, html: html, expandable_one: expandable_one, expandable_two: expandable_two}   do
      one_id = expandable_one.id
      two_id = expandable_two.id

      assert [^one_id, ^two_id] =
        get_attributes(html, ".data-dictionary-tree__field--expanded", "phx-value-field-id")

      html = render_click([view, expandable_two.target], "toggle_expanded", %{"field-id" => expandable_two.id})

      assert [^one_id] = get_attributes(html, ".data-dictionary-tree__field--expanded", "phx-value-field-id")
      assert [^two_id] = get_attributes(html, ".data-dictionary-tree__field--collapsed", "phx-value-field-id")
    end

    test "initially checkable fields are unchecked", %{html: html, checkable_one: checkable_one, checkable_two: checkable_two} do
      one_id = checkable_one.id
      two_id = checkable_two.id

      assert [^one_id, ^two_id] =
        get_attributes(html, ".data-dictionary-tree__field--unchecked", "phx-value-field-id")
    end

    test "clicking a checkable field once collapses it", %{view: view, checkable_one: checkable_one}  do
      one_id = checkable_one.id

      html = render_click([view, checkable_one.target], "toggle_checked", %{"field-id" => checkable_one.id})

      assert [^one_id] =
        get_attributes(html, ".data-dictionary-tree__field--checked", "phx-value-field-id")
    end

    test "clicking a checkable field twice toggles it", %{view: view, checkable_one: checkable_one}  do
      one_id = checkable_one.id

      _html = render_click([view, checkable_one.target], "toggle_checked", %{"field-id" => checkable_one.id})
      html = render_click([view, checkable_one.target], "toggle_checked", %{"field-id" => checkable_one.id})

      assert [^one_id | _] =
        get_attributes(html, ".data-dictionary-tree__field--unchecked", "phx-value-field-id")
    end

    test "clicking an checkable field unchecks other field (only one checked at a time)", %{view: view, html: html, checkable_one: checkable_one, checkable_two: checkable_two} do
      one_id = checkable_one.id
      two_id = checkable_two.id

      assert [^one_id, ^two_id] =
        get_attributes(html, ".data-dictionary-tree__field--unchecked", "phx-value-field-id")

      html = render_click([view, checkable_two.target], "toggle_checked", %{"field-id" => checkable_two.id})

      assert [^one_id] = get_attributes(html, ".data-dictionary-tree__field--unchecked", "phx-value-field-id")
      assert [^two_id] = get_attributes(html, ".data-dictionary-tree__field--checked", "phx-value-field-id")

      html = render_click([view, checkable_one.target], "toggle_checked", %{"field-id" => checkable_one.id})

      assert [^one_id] = get_attributes(html, ".data-dictionary-tree__field--checked", "phx-value-field-id")
      assert [^two_id] = get_attributes(html, ".data-dictionary-tree__field--unchecked", "phx-value-field-id")
    end
  end

  describe "render/1 " do
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

      DatasetCache.put(dataset)

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

      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert ["one", "two", "two-one", "three", "three-one", "three-two", "three-two-one"] == get_texts(html, ".data-dictionary-tree-field__name")
      assert ["two-one", "three-one", "three-two", "three-two-one"] == get_texts(html, ".data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name")
      assert ["three-two-one"] == get_texts(html, ".data-dictionary-tree__sub-dictionary .data-dictionary-tree__sub-dictionary .data-dictionary-tree-field__name")
      assert ["string", "map", "integer", "list", "float", "map", "string"] == get_texts(html, ".data-dictionary-tree-field__type")
    end
  end
end
