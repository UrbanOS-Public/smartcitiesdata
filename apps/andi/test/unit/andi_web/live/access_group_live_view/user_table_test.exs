defmodule AndiWeb.AccessGroupLiveView.UserTableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup

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

  describe "Basic associated users table load" do
    test "shows \"No Associated Users\" when there are no rows to show", %{conn: conn} do
      access_group = setup_access_group()
      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [], users: []})

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ "No Associated Users"
    end

    test "shows an associated user", %{conn: conn} do
      access_group = setup_access_group()
      org_title = "Constellations R Us"

      user = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: "auth0|someStringOfNumbers",
        name: "Ophiuchus",
        email: "ophiuchus@constellations.net",
        organizations: [%Andi.InputSchemas.Organization{orgTitle: "Constellations R Us"}]
      }

      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [], users: [user]})
      allow(Andi.Schemas.User.get_by_subject_id(user.subject_id), return: user)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ user.name
      assert get_text(html, ".access-groups-sub-table__cell") =~ org_title
    end

    test "shows multiple associated users", %{conn: conn} do
      access_group = setup_access_group()

      user_1 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: "auth0|someStringOfNumbers",
        name: "Penny",
        email: "penny@dogs.com",
        organizations: []
      }

      user_2 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: "auth0|someStringOfNumbersAlso",
        name: "Hazel",
        email: "hazel@dogs.com",
        organizations: []
      }

      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [], users: [user_1, user_2]})
      allow(Andi.Schemas.User.get_by_subject_id(user_1.subject_id), return: user_1)
      allow(Andi.Schemas.User.get_by_subject_id(user_2.subject_id), return: user_2)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ user_1.name
      assert get_text(html, ".access-groups-sub-table__cell") =~ user_2.name
    end

    test "shows a remove button for each user", %{conn: conn} do
      access_group = setup_access_group()

      user_1 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: "auth0|someStringOfNumbers",
        name: "Penny",
        email: "penny@dogs.com",
        organizations: []
      }

      user_2 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: "auth0|someStringOfNumbersAlso",
        name: "Hazel",
        email: "hazel@dogs.com",
        organizations: []
      }

      allow(Andi.Repo.preload(any(), any()), return: %{datasets: [], users: [user_1, user_2]})
      allow(Andi.Schemas.User.get_by_subject_id(user_1.subject_id), return: user_1)
      allow(Andi.Schemas.User.get_by_subject_id(user_2.subject_id), return: user_2)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{access_group.id}")
      text = get_text(html, ".access-groups-sub-table__cell")
      results = Regex.scan(~r/Remove/, text)

      assert length(results) == 2
    end

    defp setup_access_group() do
      access_group = TDG.create_access_group(%{})
      allow(AccessGroups.update(any()), return: %AccessGroup{id: access_group.id, name: access_group.name})
      allow(AccessGroups.get(any()), return: %AccessGroup{id: access_group.id, name: access_group.name})
      allow(Andi.InputSchemas.AccessGroup.changeset(any(), any()), return: AccessGroup.changeset(access_group))
      allow(Andi.Repo.get(Andi.InputSchemas.AccessGroup, any()), return: [])
      access_group
    end
  end
end
