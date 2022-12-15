defmodule DiscoveryApiWeb.Plugs.SetCurrentUserTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  alias DiscoveryApiWeb.Plugs.SetCurrentUser

  alias RaptorService
  alias DiscoveryApi.Schemas.Users

  describe "call/1 REQUIRE_API_KEY true" do
    setup do
      on_exit(fn -> System.put_env("REQUIRE_API_KEY", "false") end)
      System.put_env("REQUIRE_API_KEY", "true")

      :ok
    end

    test "responds with a 401 when user does not pass api_key" do
      allow(DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end)
      allow(Guardian.Plug.current_resource(any()), return: nil)

      conn = build_conn(:get, "/doesnt/matter")
      result = SetCurrentUser.call(conn, [])

      assert_called(DiscoveryApiWeb.RenderError.render_error(conn, 401, "Unauthorized: required header api_key not present"))
      assert result.halted == true
    end

    test "responds with a 401 when user passes invalid api_key" do
      allow(RaptorService.get_user_id_from_api_key(any(), any()), return: {:error, "401 error", 401})
      allow(Guardian.Plug.current_resource(any()), return: nil)
      allow(DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "invalidApiKey")

      result = SetCurrentUser.call(conn, [])

      assert_called(DiscoveryApiWeb.RenderError.render_error(conn, 401, "Unauthorized: invalid api_key"))
      assert result.halted == true
    end

    test "responds with a 401 when users call fails" do
      allow(RaptorService.get_user_id_from_api_key(any(), any()), return: {:error, "401 error", 401})
      allow(Guardian.Plug.current_resource(any()), return: nil)
      allow(DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end)
      allow(Users.get_user(any(), any()), return: {:error, "reason"})

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "invalidApiKey")

      result = SetCurrentUser.call(conn, [])

      assert_called(DiscoveryApiWeb.RenderError.render_error(conn, 401, "Unauthorized: invalid api_key"))
      assert result.halted == true
    end

    test "responds with a 500 when raptor encounters and unexpected error" do
      allow(RaptorService.get_user_id_from_api_key(any(), any()), return: {:error, "Unmatched response"})
      allow(Guardian.Plug.current_resource(any()), return: nil)
      allow(DiscoveryApiWeb.RenderError.render_error(any(), any(), any()), exec: fn conn, _, _ -> conn end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")

      result = SetCurrentUser.call(conn, [])

      assert_called(DiscoveryApiWeb.RenderError.render_error(conn, 500, "Internal Server Error"))
      assert result.halted == true
    end

    test "assigns valid current_user when user passes valid api_key" do
      userId = "userId"
      userObject = "I am a user object"

      allow(RaptorService.get_user_id_from_api_key(any(), any()), return: {:ok, userId})
      allow(Guardian.Plug.current_resource(any()), return: nil)
      allow(Users.get_user(userId, :subject_id), return: {:ok, userObject})

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")

      result = SetCurrentUser.call(conn, [])

      assert result == conn |> assign(:current_user, userObject)
    end

    test "assigns valid current_user when user passes valid current user" do
      userId = "userId"
      userObject = "I am a user object"

      allow(RaptorService.get_user_id_from_api_key(any(), any()), return: {:ok, userId})
      allow(Guardian.Plug.current_resource(any()), return: userObject)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")

      result = SetCurrentUser.call(conn, [])

      assert result == conn |> assign(:current_user, userObject)
    end
  end

  describe "call/1 REQUIRE_API_KEY false" do
    setup do
      System.put_env("REQUIRE_API_KEY", "false")

      :ok
    end

    test "assigns current_user to whatever was passed in" do
      userObject = "I am a user object"

      allow(Guardian.Plug.current_resource(any()), return: userObject)

      conn = build_conn(:get, "/doesnt/matter")

      result = SetCurrentUser.call(conn, [])

      assert result == conn |> assign(:current_user, userObject)
    end
  end
end
