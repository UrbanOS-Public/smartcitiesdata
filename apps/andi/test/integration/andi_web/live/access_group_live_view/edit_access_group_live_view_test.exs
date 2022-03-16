defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups

  @instance_name Andi.instance_name()

  @url_path "/access-groups"

  describe "curator users access" do
    test "the cancel button redirects users back to the main access groups page", %{curator_conn: conn} do
      uuid = UUID.uuid4()
      {:ok, access_group} = SmartCity.AccessGroup.new(%{name: "Smrt Access Group", id: uuid})
      AccessGroups.update(access_group)
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{uuid}")

      cancel_button = element(view, ".btn", "Cancel")

      render_click(cancel_button)
      assert_redirected(view, @url_path)
    end
  end
end
