defmodule AndiWeb.Search.ManageUsersModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organization

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  defp allowAuthUser do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
  end

  setup do
    allowAuthUser()
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "users search modal" do
    test "is closed upon hitting save", %{conn: conn} do
      mock_andi_repo()

      access_group = create_access_group()
      allow(Andi.Repo.preload(any(), [:datasets, :users]), return: %{datasets: [], users: [], id: access_group.id})
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      get_manage_users_button(view) |> render_click()

      assert element(view, ".manage-users-modal--visible") |> has_element?
      refute element(view, ".manage-users-modal--hidden") |> has_element?

      get_save_users_button(view) |> render_click()

      assert element(view, ".manage-users-modal--hidden") |> has_element?
      refute element(view, ".manage-users-modal--visible") |> has_element?
    end

    test "contains a user search field", %{conn: conn} do
      mock_andi_repo()

      access_group = create_access_group()
      allow(Andi.Repo.preload(any(), [:datasets, :users]), return: %{datasets: [], users: [], id: access_group.id})
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
      get_manage_users_button(view) |> render_click()

      assert element(view, ".manage-users-modal .search-modal__search_bar-input") |> has_element?
    end
  end

  describe "User searching in the modal" do
    test "Shows \"No Matching Users\" when there are no users to show", %{conn: conn} do
      mock_andi_repo()

      access_group = create_access_group()
      allow(Andi.Repo.preload(any(), [:datasets, :users]), return: %{datasets: [], users: [], id: access_group.id})
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
      get_manage_users_button(view) |> render_click()

      assert get_text(html, ".manage-users-modal .search-table__cell") =~ "No Matching Users"
    end

    test "Represents single user in the search results table when one exists", %{conn: conn} do
      mock_andi_repo()
      org = %Organization{orgTitle: "123"}
      user = %User{id: Ecto.UUID.generate(), name: "Joe", email: "someone@example.com", organizations: [org]}
      allow(Andi.Repo.all(any()), return: [user])
      access_group = create_access_group()
      allow(Andi.Repo.preload(any(), [:datasets, :users]), return: %{datasets: [], users: [], id: access_group.id})
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
      get_manage_users_button(view) |> render_click()

      html = render_submit(view, "user-search", %{"search-value" => "someone"})

      assert get_text(html, ".search-table__cell") =~ "Joe"
      assert get_text(html, ".manage-users-modal .search-table__cell") =~ "someone@example.com"
      assert get_text(html, ".manage-users-modal .search-table__cell") =~ "123"
    end

    test "Represents multiple users in the search results table when many exist", %{conn: conn} do
      mock_andi_repo()
      org_123 = %Organization{orgTitle: "123", id: Ecto.UUID.generate()}
      org_abc = %Organization{orgTitle: "ABC", id: Ecto.UUID.generate()}
      org_zed = %Organization{orgTitle: "Zed", id: Ecto.UUID.generate()}

      allow(Andi.Repo.all(any()),
        return: [
          %User{id: Ecto.UUID.generate(), name: "Tanya", email: "someone@example.com", organizations: [org_123]},
          %User{id: Ecto.UUID.generate(), name: "Jill", email: "someone_else@example.com", organizations: [org_abc]},
          %User{id: Ecto.UUID.generate(), name: "Alice", email: "completely_different@example.com", organizations: [org_zed]}
        ]
      )

      access_group = create_access_group()
      allow(Andi.Repo.preload(any(), [:datasets, :users]), return: %{datasets: [], users: [], id: access_group.id})
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      get_manage_users_button(view) |> render_click()

      html = render_submit(view, "user-search", %{"search-value" => "example"})

      assert get_text(html, ".search-table__cell") =~ "Tanya"
      assert get_text(html, ".search-table__cell") =~ "someone@example.com"
      assert get_text(html, ".search-table__cell") =~ "123"
      assert get_text(html, ".search-table__cell") =~ "Jill"
      assert get_text(html, ".search-table__cell") =~ "someone_else@example.com"
      assert get_text(html, ".search-table__cell") =~ "ABC"
      assert get_text(html, ".search-table__cell") =~ "Alice"
      assert get_text(html, ".search-table__cell") =~ "completely_different@example.com"
      assert get_text(html, ".search-table__cell") =~ "Zed"
    end
  end

  defp mock_andi_repo() do
    allow(AccessGroups.update(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
    allow(AccessGroups.get(any()), return: %AccessGroup{id: UUID.uuid4(), name: "group"})
    allow(Andi.Repo.get(Andi.InputSchemas.AccessGroup, any()), return: [])
  end

  defp create_access_group() do
    uuid = UUID.uuid4()
    access_group = TDG.create_access_group(%{name: "Smrt Access Group", id: uuid})
    AccessGroups.update(access_group)
    access_group
  end

  defp get_manage_users_button(view) do
    element(view, ".btn", "Manage Users")
  end

  defp get_save_users_button(view) do
    element(view, ".manage-users-modal .save-search")
  end
end
