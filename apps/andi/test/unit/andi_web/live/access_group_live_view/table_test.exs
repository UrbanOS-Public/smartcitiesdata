defmodule AndiWeb.AccessGroupLiveView.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]
  import Mock

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  setup_with_mocks([
    {Andi.Repo, [], [
      get_by: fn(Andi.Schemas.User, _) -> @user end
    ]},
    {User, [], [
      get_all: fn() -> [@user] end,
      get_by_subject_id: fn(_) -> @user end
    ]},
    {Guardian.DB.Token, [], [find_by_claims: fn(_) -> nil end]}
  ]) do
    :ok
  end

  describe "Basic access groups page load" do
    test "shows \"No Access Groups Found!\" when there are no rows to show", %{conn: conn} do
      with_mock(Andi.InputSchemas.AccessGroups, [get_all: fn() -> [] end]) do
        assert {:ok, view, html} = live(conn, @url_path)

        assert get_text(html, ".access-groups-table__cell") =~ "No Access Groups Found!"
      end
    end

    test "represents an Access Group when one exists", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      with_mock(Andi.InputSchemas.AccessGroups, [get_all: fn() -> [%{name: group_name, id: group_id, updated_at: updated_at}] end]) do
        assert {:ok, view, html} = live(conn, @url_path)

        assert get_text(html, ".access-groups-table__cell") =~ group_name
      end
    end

    test "displays 'Modified Date' attribute correctly", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      with_mock(Andi.InputSchemas.AccessGroups, [get_all: fn() -> [%{name: group_name, id: group_id, updated_at: updated_at}] end]) do
        assert {:ok, view, html} = live(conn, @url_path)

        expected_time_string = Timex.format!(updated_at, "{M}-{D}-{YYYY}")
        assert get_text(html, ".access-groups-table__cell") =~ expected_time_string
      end
    end

    test "represents Access Groups when multiple exist", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      with_mock(Andi.InputSchemas.AccessGroups, [get_all: fn() -> [%{name: group_name, id: group_id, updated_at: updated_at}, %{name: "group2", id: UUID.uuid4(), updated_at: updated_at}] end]) do
        assert {:ok, view, html} = live(conn, @url_path)

        assert get_text(html, ".access-groups-table__cell") =~ group_name
        assert get_text(html, ".access-groups-table__cell") =~ "group2"
      end
    end
  end
end
