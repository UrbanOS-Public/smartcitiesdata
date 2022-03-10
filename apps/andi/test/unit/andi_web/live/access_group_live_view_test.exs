defmodule AndiWeb.AccessGroupLiveViewTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_values: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()

  setup do
    allow(Andi.Repo.get_by(any(), any()), return: @user)
    #   allow(User.get_all(), return: [@user])
    #   allow(User.get_by_subject_id(any()), return: @user)
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "Basic live page load" do
    # test "loads all datasets", %{conn: conn} do
    #   datasets =
    #     Enum.map(
    #       1..3,
    #       fn _x ->
    #         DatasetHelpers.create_dataset(%{})
    #       end
    #     )

    #   allow(Andi.Repo.all(any()), return: datasets)
    #   DatasetHelpers.replace_all_datasets_in_repo(datasets)

    #   assert {:ok, _view, html} = live(conn, @url_path)

    #   table_text = get_text(html, ".datasets-index__table")

    #   Enum.each(datasets, fn dataset ->
    #     assert table_text =~ dataset.business.dataTitle
    #   end)
    # end

    test "shows No Access Groups when there are no rows to show", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])
      # DatasetHelpers.replace_all_datasets_in_repo([])

      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".access-groups-index__title") =~ "Access Groups"
      assert get_text(html, ".access-groups-index__table") =~ "No Access Groups"
    end
  end
end
