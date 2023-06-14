defmodule AndiWeb.AccessGroupLiveView.ManageUsersModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias Andi.Schemas.User

  import Mock
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

  setup_with_mocks([
    {Guardian.DB.Token, [], [find_by_claims: fn(_) -> nil end]}
  ]) do
    []
  end

  describe "users search modal" do
    test "is closed upon hitting save", %{conn: conn} do
      access_group_id = UUID.uuid4()
      org = %Organization{orgTitle: "123"}

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [%User{id: Ecto.UUID.generate(), name: "Joe", email: "someone@example.com", organizations: [org]}] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group_id} end,
          get_by: fn(Andi.Schemas.User, _) -> @user end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)

        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        get_manage_users_button(view) |> render_click()

        assert element(view, ".manage-users-modal--visible") |> has_element?
        refute element(view, ".manage-users-modal--hidden") |> has_element?

        get_save_users_button(view) |> render_click()

        assert element(view, ".manage-users-modal--hidden") |> has_element?
        refute element(view, ".manage-users-modal--visible") |> has_element?
      end
    end

    test "contains a user search field", %{conn: conn} do
      access_group_id = UUID.uuid4()
      org = %Organization{orgTitle: "123"}

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [%User{id: Ecto.UUID.generate(), name: "Joe", email: "someone@example.com", organizations: [org]}] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group_id} end,
          get_by: fn(Andi.Schemas.User, _) -> @user end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
        get_manage_users_button(view) |> render_click()

        assert element(view, ".manage-users-modal .search-modal__search_bar-input") |> has_element?
      end
    end
  end

  describe "User searching in the modal" do
    test "Shows \"No Matching Users\" when there are no users to show", %{conn: conn} do
      access_group_id = UUID.uuid4()
      org = %Organization{orgTitle: "123"}

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [%User{id: Ecto.UUID.generate(), name: "Joe", email: "someone@example.com", organizations: [org]}] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          preload: fn(_, _) -> %{datasets: [], users: [], id: access_group_id} end,
          get_by: fn(Andi.Schemas.User, _) -> @user end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)

        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")
        get_manage_users_button(view) |> render_click()

        assert get_text(html, ".manage-users-modal .search-table__cell") =~ "No Matching Users"
      end
    end

    test "Represents single user in the search results table when one exists", %{conn: conn} do
      access_group_id = UUID.uuid4()
      org = %Organization{orgTitle: "123"}
      user = %User{id: Ecto.UUID.generate(), name: "Joe", email: "someone@example.com", organizations: [org]}

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [user] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          get_by: fn
            (Andi.Schemas.User, _) -> user
          end,
          preload: fn
            (_, [:datasets, :users]) -> %{datasets: [], users: [], id: access_group_id}
            (_, [:datasets, :organizations]) -> %{datasets: [], users: [], id: access_group_id}
          end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")
        get_manage_users_button(view) |> render_click()

        html = render_submit(view, "user-search", %{"search-value" => "someone"})

        assert get_text(html, ".search-table__cell") =~ "Joe"
        assert get_text(html, ".manage-users-modal .search-table__cell") =~ "someone@example.com"
        assert get_text(html, ".manage-users-modal .search-table__cell") =~ "123"
      end
    end

    test "Represents multiple users in the search results table when many exist", %{conn: conn} do
      access_group_id = UUID.uuid4()
      org_123 = %Organization{orgTitle: "123", id: Ecto.UUID.generate()}
      org_abc = %Organization{orgTitle: "ABC", id: Ecto.UUID.generate()}
      org_zed = %Organization{orgTitle: "Zed", id: Ecto.UUID.generate()}

      user_1 = %User{id: Ecto.UUID.generate(), name: "Tanya", email: "someone@example.com", organizations: [org_123]}
      user_2 = %User{id: Ecto.UUID.generate(), name: "Jill", email: "someone_else@example.com", organizations: [org_abc]}
      user_3 = %User{id: Ecto.UUID.generate(), name: "Alice", email: "completely_different@example.com", organizations: [org_zed]}

      with_mocks([
        {AccessGroups, [], [
          update: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end,
          get: fn(_) -> %AccessGroup{id: UUID.uuid4(), name: "group"} end
        ]},
        {Andi.Repo, [], [
          all: fn(_) -> [user_1, user_2, user_3] end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end,
          get_by: fn
            (Andi.Schemas.User, _) -> user_1
          end,
          preload: fn
            (_, [:datasets, :users]) -> %{datasets: [], users: [], id: access_group_id}
            (_, [:datasets, :organizations]) -> %{datasets: [], users: [], id: access_group_id}
          end
        ]}
      ]) do
        access_group = create_access_group(access_group_id)
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group_id}")

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
  end

  defp create_access_group(uuid) do
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
