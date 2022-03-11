defmodule AndiWeb.AccessGroupLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_values: 2]

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
      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".message") =~ "No Access Groups"
    end
  end

  defp encoded(url) do
    String.replace(url, " ", "+")
  end
end
