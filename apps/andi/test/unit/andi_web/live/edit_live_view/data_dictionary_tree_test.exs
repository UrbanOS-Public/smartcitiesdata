defmodule AndiWeb.EditLiveView.DataDictionaryTreeTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_texts: 2,
      get_select: 2,
      get_attributes: 3,
      find_elements: 2
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

      [expandable_one_id, expandable_two_id] =
        get_attributes(html, ".data-dictionary-tree-field__action[phx-click='toggle_expanded']", "phx-value-field-id")

      [expandable_one_target, expandable_two_target] =
        get_attributes(html, ".data-dictionary-tree-field__action[phx-click='toggle_expanded']", "phx-target")

      [checkable_one_id, _, _, checkable_two_id] =
        get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-value-field-id")

      [checkable_one_target, _, _, checkable_two_target] =
        get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-target")

      [
        view: view,
        html: html,
        expandable_one: %{id: expandable_one_id, target: expandable_one_target, name: "one"},
        expandable_two: %{id: expandable_two_id, target: expandable_two_target},
        checkable_one: %{id: checkable_one_id, target: checkable_one_target, name: "one", type: "list"},
        checkable_two: %{id: checkable_two_id, target: checkable_two_target}
      ]
    end

    test "first field is selected by default", %{html: html, expandable_one: expandable_one} do
      one_id = expandable_one.id

      assert [^one_id] = get_action_field_ids(html, "selected")
    end

    test "first field values are displayed in the editor by default", %{html: html, expandable_one: expandable_one} do
      assert [expandable_one.name] == get_attributes(html, ".data-dictionary-field-editor__name", "value")
    end

    test "initially expandable fields are expanded", %{html: html, expandable_one: expandable_one, expandable_two: expandable_two} do
      one_id = expandable_one.id
      two_id = expandable_two.id

      assert [^one_id, ^two_id] = get_action_field_ids(html, "expanded")
    end

    test "clicking an expandable field once collapses it", %{view: view, expandable_one: expandable_one} do
      one_id = expandable_one.id

      html = render_click([view, expandable_one.target], "toggle_expanded", %{"field-id" => expandable_one.id})

      assert [^one_id] = get_action_field_ids(html, "collapsed")
    end

    test "clicking an expandable field twice toggles it", %{view: view, expandable_one: expandable_one} do
      one_id = expandable_one.id

      _html = render_click([view, expandable_one.target], "toggle_expanded", %{"field-id" => expandable_one.id})
      html = render_click([view, expandable_one.target], "toggle_expanded", %{"field-id" => expandable_one.id})

      assert [^one_id | _] = get_action_field_ids(html, "expanded")
    end

    test "clicking an expandable field does not affect another field", %{
      view: view,
      html: html,
      expandable_one: expandable_one,
      expandable_two: expandable_two
    } do
      one_id = expandable_one.id
      two_id = expandable_two.id

      assert [^one_id, ^two_id] = get_action_field_ids(html, "expanded")

      html = render_click([view, expandable_two.target], "toggle_expanded", %{"field-id" => expandable_two.id})

      assert [^one_id] = get_action_field_ids(html, "expanded")
      assert [^two_id] = get_action_field_ids(html, "collapsed")
    end

    test "clicking a selectable and expandable field once selects it but leaves it expanded", %{view: view, checkable_one: checkable_one} do
      one_id = checkable_one.id

      html = render_click([view, checkable_one.target], "toggle_selected", %{"field-id" => checkable_one.id})

      assert [^one_id] = get_action_field_ids(html, "selected")
      assert [^one_id | _] = get_action_field_ids(html, "expanded")
    end

    test "clicking a selectable and checkable field once selects and checks it", %{view: view, checkable_two: checkable_two} do
      two_id = checkable_two.id

      html = render_click([view, checkable_two.target], "toggle_selected", %{"field-id" => checkable_two.id})

      assert [^two_id] = get_action_field_ids(html, "selected")
      assert [^two_id | _] = get_action_field_ids(html, "checked")
    end

    test "clicking a checkable field twice does not unselect it", %{view: view, checkable_one: checkable_one} do
      one_id = checkable_one.id

      _html = render_click([view, checkable_one.target], "toggle_selected", %{"field-id" => checkable_one.id})
      html = render_click([view, checkable_one.target], "toggle_selected", %{"field-id" => checkable_one.id})

      assert [^one_id] = get_action_field_ids(html, "selected")
    end

    test "clicking a selectable field unselects other field (only one checked at a time)", %{
      view: view,
      html: html,
      checkable_one: checkable_one,
      checkable_two: checkable_two
    } do
      one_id = checkable_one.id
      two_id = checkable_two.id

      assert one_id in get_action_field_ids(html, "selected")
      assert two_id in get_action_field_ids(html, "unselected")

      html = render_click([view, checkable_two.target], "toggle_selected", %{"field-id" => checkable_two.id})

      assert one_id in get_action_field_ids(html, "unselected")
      assert two_id in get_action_field_ids(html, "selected")

      html = render_click([view, checkable_one.target], "toggle_selected", %{"field-id" => checkable_one.id})

      assert one_id in get_action_field_ids(html, "selected")
      assert two_id in get_action_field_ids(html, "unselected")
    end

    test "clicking a checkable field fills the field editor with its corresponding values", %{view: view, checkable_one: checkable_one} do
      # one_id = checkable_one.id
      one_name = checkable_one.name
      one_type = checkable_one.type

      _html = render_click([view, checkable_one.target], "toggle_selected", %{"field-id" => checkable_one.id})

      eventually(fn ->
        html = render(view)
        assert [one_name] == get_attributes(html, ".data-dictionary-field-editor__name", "value")
        assert {one_type, Macro.camelize(one_type)} == get_select(html, ".data-dictionary-field-editor__type")
      end)
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

      assert ["one", "two", "two-one", "three", "three-one", "three-two", "three-two-one"] ==
               get_texts(html, ".data-dictionary-tree-field__name")

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

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(find_elements(html, "input[type='hidden']#form_data_schema_0_description"))
      assert Enum.count(find_elements(html, "input[type='hidden']#form_data_schema_1_description")) > 0
    end

    test "handles datasets with no schema fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{}) |> Map.update(:technical, %{}, &Map.delete(&1, :schema))

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "handles datasets with empty schema fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{schema: []})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end
  end

  def get_action_field_ids(html, action) do
    get_attributes(html, ".data-dictionary-tree__field--#{action} > .data-dictionary-tree-field__action", "phx-value-field-id")
  end
end
