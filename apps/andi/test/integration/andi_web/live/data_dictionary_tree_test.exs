defmodule AndiWeb.DataDictionary.TreeTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.Datasets
  alias SmartCity.TestDataGenerator, as: TDG

  import FlokiHelpers,
    only: [
      get_select: 2,
      get_attributes: 3
    ]

  @endpoint AndiWeb.Endpoint
  @url_path "/submissions/"

  describe "expand/collapse and check/uncheck" do
    setup %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{
                name: "one",
                type: "list",
                itemType: "map",
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

      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      [expandable_one_id, expandable_two_id] =
        get_attributes(html, ".data-dictionary-tree-field__action[phx-click='toggle_expanded']", "phx-value-field-id")

      [expandable_one_target, expandable_two_target] =
        get_attributes(html, ".data-dictionary-tree-field__action[phx-click='toggle_expanded']", "phx-target")

      [checkable_one_id, _, _, checkable_two_id] =
        get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-value-field-id")

      [checkable_one_target, _, _, checkable_two_target] =
        get_attributes(html, ".data-dictionary-tree-field__text[phx-click='toggle_selected']", "phx-target")

      [
        view: data_dictionary_view,
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

      expandable = element(view, ".data-dictionary-tree-field__action[phx-value-field-id='#{one_id}']")

      html = render_click(expandable)

      assert [^one_id] = get_action_field_ids(html, "collapsed")
    end

    test "clicking an expandable field twice toggles it", %{view: view, expandable_one: expandable_one} do
      one_id = expandable_one.id

      expandable = element(view, ".data-dictionary-tree-field__action[phx-value-field-id='#{one_id}']")

      _html = render_click(expandable)
      html = render_click(expandable)

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

      expandable = element(view, ".data-dictionary-tree-field__action[phx-value-field-id='#{two_id}']")
      html = render_click(expandable)

      assert [^one_id] = get_action_field_ids(html, "expanded")
      assert [^two_id] = get_action_field_ids(html, "collapsed")
    end

    test "clicking a selectable and expandable field once selects it but leaves it expanded", %{view: view, checkable_one: checkable_one} do
      one_id = checkable_one.id
      selectable = element(view, ".data-dictionary-tree-field__text[phx-value-field-id='#{one_id}']")

      html = render_click(selectable)

      assert [^one_id] = get_action_field_ids(html, "selected")
      assert [^one_id | _] = get_action_field_ids(html, "expanded")
    end

    test "clicking a selectable and checkable field once selects and checks it", %{view: view, checkable_two: checkable_two} do
      two_id = checkable_two.id

      selectable = element(view, ".data-dictionary-tree-field__text[phx-value-field-id='#{two_id}']")
      html = render_click(selectable)

      assert [^two_id] = get_action_field_ids(html, "selected")
      assert [^two_id | _] = get_action_field_ids(html, "checked")
    end

    test "clicking a checkable field twice does not unselect it", %{view: view, checkable_one: checkable_one} do
      one_id = checkable_one.id

      selectable = element(view, ".data-dictionary-tree-field__text[phx-value-field-id='#{one_id}']")
      _html = render_click(selectable)
      html = render_click(selectable)

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

      selectable_one = element(view, ".data-dictionary-tree-field__text[phx-value-field-id='#{one_id}']")
      selectable_two = element(view, ".data-dictionary-tree-field__text[phx-value-field-id='#{two_id}']")

      html = render_click(selectable_two)

      assert one_id in get_action_field_ids(html, "unselected")
      assert two_id in get_action_field_ids(html, "selected")

      html = render_click(selectable_one)

      assert one_id in get_action_field_ids(html, "selected")
      assert two_id in get_action_field_ids(html, "unselected")
    end

    test "clicking a checkable field fills the field editor with its corresponding values", %{view: view, checkable_one: checkable_one} do
      one_id = checkable_one.id
      one_name = checkable_one.name
      one_type = checkable_one.type

      selectable = element(view, ".data-dictionary-tree-field__text[phx-value-field-id='#{one_id}']")

      _html = render_click(selectable)

      eventually(fn ->
        html = render(view)
        assert [one_name] == get_attributes(html, ".data-dictionary-field-editor__name", "value")
        assert {one_type, Macro.camelize(one_type)} == get_select(html, ".data-dictionary-field-editor__type")
      end)
    end
  end

  def get_action_field_ids(html, action) do
    get_attributes(html, ".data-dictionary-tree__field--#{action} > .data-dictionary-tree-field__action", "phx-value-field-id")
  end
end
