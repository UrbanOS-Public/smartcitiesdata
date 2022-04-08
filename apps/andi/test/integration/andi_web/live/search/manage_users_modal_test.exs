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

  test "successfully can add a user to the list of selected users", %{curator_conn: conn} do
    {:ok, user} = User.create_or_update("auth0|123458", %{email: "test@example.com", name: "TestingTurtle"})
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => user.name})

    html = find_add_user_button(view) |> render_click

    assert get_text(html, ".selected-results-from-search") =~ user.name
  end

  test "sucessfully can remove a user from the list of selected users", %{curator_conn: conn} do
    {:ok, user} = User.create_or_update("auth0|12345812", %{email: "test@example.com", name: "TestingLadybug"})
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => user.name})

    html = find_add_user_button(view) |> render_click

    assert get_text(html, ".selected-results-from-search") =~ user.name

    remove_action = element(view, ".access-groups-sub-table__cell--break.modal-action-text", "Remove")
    html = render_click(remove_action)

    refute get_text(html, ".selected-results-from-search") =~ user.name
  end

  test "selected users are persisted when a new search is made", %{curator_conn: conn} do
    {:ok, user} = User.create_or_update("auth0|123458", %{email: "test@example.com", name: "TestingLeopard"})
    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => user.name})

    html = find_add_user_button(view) |> render_click

    assert get_text(html, ".selected-results-from-search") =~ user.name

    html = render_submit(view, "user-search", %{"search-value" => "second search value"})

    assert get_text(html, ".selected-results-from-search") =~ user.name
  end

  test "shows all of a user's organizations", %{curator_conn: conn} do
    {:ok, org1} = TDG.create_organization(%{}) |> Organizations.update()
    {:ok, org2} = TDG.create_organization(%{}) |> Organizations.update()
    {:ok, user} = User.create_or_update("auth0|000000", %{email: "organized@example.com", name: "Organizer"})
    {:ok, associate1} = UserOrganizationAssociate.new(%{subject_id: user.subject_id, org_id: org1.id, email: user.email})
    {:ok, associate2} = UserOrganizationAssociate.new(%{subject_id: user.subject_id, org_id: org2.id, email: user.email})
    Brook.Event.send(Andi.instance_name(), user_organization_associate(), :testing, associate1)
    Brook.Event.send(Andi.instance_name(), user_organization_associate(), :testing, associate2)

    eventually(fn ->
      user = User.get_by_subject_id(user.subject_id) |> Andi.Repo.preload(:organizations)
      assert org1 in user.organizations
      assert org2 in user.organizations
    end)

    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => org1.orgTitle})

    assert get_text(html, ".search-table") =~ org1.orgTitle
    assert get_text(html, ".search-table") =~ org2.orgTitle
  end

  test "shows helpful message if no results returned", %{curator_conn: conn} do
    {:ok, _user} = User.create_or_update("auth0|000000", %{email: "real_person@example.com", name: "Real Person"})

    access_group = create_access_group()
    assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

    find_manage_users_button(view) |> render_click
    html = render_submit(view, "user-search", %{"search-value" => "Fake"})

    assert get_text(html, ".search-table") =~ "No Matching Users"
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

  defp find_add_user_button(view) do
    element(view, ".modal-action-text", "Select")
  end
end
