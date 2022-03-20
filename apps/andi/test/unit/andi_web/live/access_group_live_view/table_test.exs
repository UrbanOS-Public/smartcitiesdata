defmodule AndiWeb.AccessGroupLiveView.TableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

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

  describe "Basic access groups page load" do
    test "shows \"No Access Groups\" when there are no rows to show", %{conn: conn} do
      allow(Andi.InputSchemas.AccessGroups.get_all(), return: [])
      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-table__cell") =~ "No Access Groups"
    end

    test "represents an Access Group when one exists", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()
      allow(Andi.InputSchemas.AccessGroups.get_all(), return: [%{name: group_name, id: group_id, updated_at: updated_at}])

      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-table__cell") =~ group_name
    end

    test "displays 'Modified Date' attribute correctly", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()
      allow(Andi.InputSchemas.AccessGroups.get_all(), return: [%{name: group_name, id: group_id, updated_at: updated_at}])

      assert {:ok, view, html} = live(conn, @url_path)

      expected_time_string = Timex.format!(updated_at, "{M}-{D}-{YYYY}")
      assert get_text(html, ".access-groups-table__cell") =~ expected_time_string
    end

    test "represents Access Groups when multiple exist", %{conn: conn} do
      group_name = "group-one"
      group_id = UUID.uuid4()
      updated_at = DateTime.utc_now()

      allow(Andi.InputSchemas.AccessGroups.get_all(),
        return: [%{name: group_name, id: group_id, updated_at: updated_at}, %{name: "group2", id: UUID.uuid4(), updated_at: updated_at}]
      )

      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-table__cell") =~ group_name
      assert get_text(html, ".access-groups-table__cell") =~ "group2"
    end
  end
end
