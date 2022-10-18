defmodule AndiWeb.HeaderLiveViewTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import Checkov
  import FlokiHelpers,
    only: [
      find_elements: 2
    ]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"

  describe "non-curator view" do
    test "organization button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, "#organizations-link"))
    end

    test "access groups button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, "#access-groups-link"))
    end

    test "ingestions button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, "#ingestions-link"))
    end

    test "users button is not shown", %{public_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      assert Enum.empty?(find_elements(html, "#users-link"))
    end
  end

  describe "curator view" do
    test "organization button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, "#organizations-link"))
    end

    test "access groups button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, "#access-groups-link"))
    end

    test "ingestions button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, "#ingestions-link"))
    end

    test "users button is shown", %{curator_conn: conn} do
      {:ok, _view, html} = live(conn, @url_path)

      refute Enum.empty?(find_elements(html, "#users-link"))
    end

    test "access groups button links to the access groups page", %{curator_conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      access_groups_button = element(view, "#access-groups-link")

      render_click(access_groups_button)
      assert_redirected(view, "/access-groups")
    end

    test "ingestions button links to the ingestions page", %{curator_conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      ingestions_button = element(view, "#ingestions-link")

      render_click(ingestions_button)
      assert_redirected(view, "/ingestions")
    end
  end

  describe "accessibility" do
    data_test "#{button} button responds to #{key_type}", %{curator_conn: conn} do
      {:ok, view, _html} = live(conn, @url_path)

      datasets_button = element(view, selector)
      render_keydown(datasets_button, %{"key" => key})
      assert_redirected(view, redirect)

      where ([
          [:button, :key_type, :selector, :key, :redirect],
          ["datasets", "enter", "#datasets-link", "Enter", "/datasets"],
          ["datasets", "space", "#datasets-link", " ", "/datasets"],
          ["ingestions", "enter", "#ingestions-link", "Enter", "/ingestions"],
          ["ingestions", "space", "#ingestions-link", " ", "/ingestions"],
          ["organizations", "enter", "#organizations-link", "Enter", "/organizations"],
          ["organizations", "space", "#organizations-link", " ", "/organizations"],
          ["access groups", "enter", "#access-groups-link", "Enter", "/access-groups"],
          ["access groups", "space", "#access-groups-link", " ", "/access-groups"],
          ["users", "enter", "#users-link", "Enter", "/users"],
          ["users", "space", "#users-link", " ", "/users"],
          ["log-out", "enter", "#log-out-link", "Enter", "/auth/auth0/logout"],
          ["log-out", "space", "#log-out-link", " ", "/auth/auth0/logout"]
        ])
    end
  end
end
