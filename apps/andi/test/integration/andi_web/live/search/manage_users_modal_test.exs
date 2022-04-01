defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_text: 2
    ]
  import SmartCity.Event,
    only: [
      user_organization_associate: 0
    ]
  import SmartCity.TestHelper, only: [eventually: 1]
  alias SmartCity.UserOrganizationAssociate
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.Organizations
  alias Andi.Schemas.User

  @url_path "/access-groups"

  test "button opens the user search modal", %{curator_conn: conn} do
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click

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

  test "searches on email", %{curator_conn: conn} do
    {:ok, user} = User.create_or_update("auth0|123456", %{email: "test@example.com", name: "Tester"})
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => user.email})

    assert get_text(html, ".search-table") =~ user.email
  end

  test "searches on name", %{curator_conn: conn} do
    {:ok, user} = User.create_or_update("auth0|654321", %{email: "samuel@example.com", name: "Samuel"})
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => user.name})

    assert get_text(html, ".search-table") =~ user.name
  end

  test "searches on organization", %{curator_conn: conn} do
    {:ok, org} = TDG.create_organization(%{}) |> Organizations.update()
    {:ok, user} = User.create_or_update("auth0|000000", %{email: "organized@example.com", name: "Organizer"})
    {:ok, associate} = UserOrganizationAssociate.new(%{subject_id: user.subject_id, org_id: org.id, email: user.email})
    Brook.Event.send(Andi.instance_name(), user_organization_associate(), :testing, associate)
    eventually(fn ->
      user = User.get_by_subject_id(user.subject_id) |> Andi.Repo.preload(:organizations)
      assert org in user.organizations
    end)
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => org.orgTitle})

    assert get_text(html, ".search-table") =~ org.orgTitle
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
