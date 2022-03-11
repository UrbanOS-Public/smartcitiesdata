defmodule AndiWeb.HeaderLiveViewTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      find_elements: 2
    ]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"

  describe "non-curator view" do
    test "organization button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, ".organization-link"))
    end

    test "access groups button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, ".access-group-link"))
    end

    test "users button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, ".user-link"))
    end
  end

  describe "curator view" do
    test "organization button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, ".organization-link"))
    end

    test "access groups button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, ".access-group-link"))
    end

    test "users button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, ".user-link"))
    end

    test "access groups button links to the access groups page", %{curator_conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      access_groups_button = element(view, ".access-group-link")

      render_click(access_groups_button)
      assert_redirected(view, "/access-groups")
    end
  end
end
