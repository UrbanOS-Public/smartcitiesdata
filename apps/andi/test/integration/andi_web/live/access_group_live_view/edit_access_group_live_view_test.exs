defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2,
      get_attributes: 3
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups

  @instance_name Andi.instance_name()

  @url_path "/access-groups"

  describe "curator users access" do
    test "the access group name field is alterable", %{curator_conn: conn} do
      uuid = UUID.uuid4()
      access_group = TDG.create_access_group(%{name: "old-group-name", id: uuid})
      AccessGroups.update(access_group)
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{uuid}")

      new_access_group_name = "new-group-name"
      form_data = %{"name" => new_access_group_name, "id" => uuid}

      render_change(view, "form_change", %{"form_data" => form_data, "_target" => ["form_data", "name"]})

      save_btn = element(view, ".btn", "Save")
      render_click(save_btn)

      eventually(fn ->
        group = AccessGroups.get(uuid)
        assert group != nil
        assert group.name == new_access_group_name
      end)
    end

    test "the access group name is loaded into the name field upon load", %{curator_conn: conn} do
      access_group_name = "cool-group-name"
      uuid = UUID.uuid4()
      access_group = TDG.create_access_group(%{name: access_group_name, id: uuid})
      AccessGroups.update(access_group)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{uuid}")

      assert [access_group_name] = get_attributes(html, "#form_data_name", "value")
    end

    test "the cancel button redirects users back to the main access groups page", %{curator_conn: conn} do
      uuid = UUID.uuid4()
      access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
      AccessGroups.update(access_group)
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{uuid}")

      cancel_button = element(view, ".btn", "Cancel")

      render_click(cancel_button)
      assert_redirected(view, @url_path)
    end
  end
end
