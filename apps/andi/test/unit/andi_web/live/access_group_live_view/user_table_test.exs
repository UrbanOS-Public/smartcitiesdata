defmodule AndiWeb.AccessGroupLiveView.UserTableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]
  import Mock

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  alias Andi.Schemas.User

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()
  @access_group TDG.create_access_group(%{})

  setup_with_mocks([
    {Andi.Repo, [], [
      get_by: fn(Andi.Schemas.User, _) -> @user end,
      get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
    ]},
    {User, [], [
      get_all: fn() -> [@user] end,
      get_by_subject_id: fn(_) -> @user end
    ]},
    {AccessGroups, [], [
      update: fn(_) -> %AccessGroup{id: @access_group.id, name: @access_group.name} end,
      get: fn(_) -> %AccessGroup{id: @access_group.id, name: @access_group.name} end
    ]},
    {Guardian.DB.Token, [], [find_by_claims: fn(_) -> nil end]}
  ]) do
    :ok
  end

  describe "Basic associated users table load" do
    test "shows \"No Associated Users\" when there are no rows to show", %{conn: conn} do

      with_mock(Andi.Repo, [
        preload: fn(_, _) -> %{datasets: [], users: [], id: @access_group.id} end,
        get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
      ]) do
        assert {:ok, view, html} = live(conn, "#{@url_path}/#{@access_group.id}")

        assert get_text(html, ".access-groups-sub-table__cell") =~ "No Associated Users"
      end
    end

    test "shows an associated user", %{conn: conn} do
      org_title = "Constellations R Us"

      access_group_id = @access_group.id

      user_subject_id = "auth0|someStringOfNumbers"
      user = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_subject_id,
        name: "Ophiuchus",
        email: "ophiuchus@constellations.net",
        organizations: [%Andi.InputSchemas.Organization{orgTitle: "Constellations R Us"}]
      }

      with_mocks([
        {Andi.Repo, [], [
          preload: fn(_, [:datasets, :users]) -> %{datasets: [], users: [user], id: access_group_id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]},
        {Andi.Schemas.User, [], [get_by_subject_id: fn(user_subject_id) -> user end]}
      ]) do
        assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        assert get_text(html, ".access-groups-sub-table__cell") =~ user.name
        assert get_text(html, ".access-groups-sub-table__cell") =~ org_title
      end
    end

    test "shows multiple associated users", %{conn: conn} do
      access_group_id = @access_group.id

      user_1_subject_id = "auth0|someStringOfNumbers"
      user_1 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_1_subject_id,
        name: "Penny",
        email: "penny@dogs.com",
        organizations: []
      }

      user_2_subject_id = "auth0|someStringOfNumbersAlso"
      user_2 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_2_subject_id,
        name: "Hazel",
        email: "hazel@dogs.com",
        organizations: []
      }

      with_mocks([
        {Andi.Repo, [], [
          preload: fn(_, _) -> %{datasets: [], users: [user_1, user_2], id: access_group_id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]},
        {Andi.Schemas.User, [], [
          get_by_subject_id: fn
            (^user_1_subject_id) -> user_1
            (^user_2_subject_id) -> user_2
            (_) -> @user
          end
        ]}
      ]) do
        assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")

        assert get_text(html, ".access-groups-sub-table__cell") =~ user_1.name
        assert get_text(html, ".access-groups-sub-table__cell") =~ user_2.name
      end
    end

    test "shows a remove button for each user", %{conn: conn} do
      access_group_id = @access_group.id

      user_1_subject_id = "auth0|someStringOfNumbers"
      user_1 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_1_subject_id,
        name: "Penny",
        email: "penny@dogs.com",
        organizations: []
      }

      user_2_subject_id = "auth0|someStringOfNumbersAlso"
      user_2 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_2_subject_id,
        name: "Hazel",
        email: "hazel@dogs.com",
        organizations: []
      }

      with_mocks([
        {Andi.Repo, [], [
          preload: fn(_, _) -> %{datasets: [], users: [user_1, user_2], id: access_group_id} end,
          get: fn(Andi.InputSchemas.AccessGroup, _) -> [] end
        ]},
        {Andi.Schemas.User, [], [
          get_by_subject_id: fn
            (^user_1_subject_id) -> user_1
            (^user_2_subject_id) -> user_2
            (_) -> @user
          end
        ]}
      ]) do
        assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")
        text = get_text(html, ".access-groups-sub-table__cell")
        results = Regex.scan(~r/Remove/, text)

        assert length(results) == 2
      end
    end
  end
end
