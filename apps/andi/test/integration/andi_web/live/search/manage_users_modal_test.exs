defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.AccessGroups

  @url_path "/access-groups"

  test "button opens the user search modal", %{curator_conn: conn} do
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    element(view, ".btn", "Manage Users") |> render_click

    assert element(view, ".manage-users-modal--visible") |> has_element?
  end

  test "closes modal on click", %{curator_conn: conn} do
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click

    save_button = element(view, ".manage-users-modal .save-search", "Save")

    render_click(save_button)

    refute Enum.empty?(find_elements(html, ".manage-users-modal--hidden"))
  end

  defp create_access_group() do
    uuid = UUID.uuid4()
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end

  defp find_manage_users_button(view) do
    element(view, ".btn", "Manage Users")
  end
end
