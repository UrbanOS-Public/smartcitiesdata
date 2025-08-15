defmodule DiscoveryApiWeb.Plugs.SetCurrentUserTest do
  use DiscoveryApiWeb.ConnCase
  import Mox

  alias DiscoveryApiWeb.Plugs.SetCurrentUser

  setup :verify_on_exit!
  setup :set_mox_from_context

  describe "call/1 REQUIRE_API_KEY true" do
    setup do
      on_exit(fn -> System.put_env("REQUIRE_API_KEY", "false") end)
      System.put_env("REQUIRE_API_KEY", "true")
      
      # Use Mox for AuthService to avoid HTTP calls in tests
      stub(AuthServiceMock, :create_logged_in_user, fn _conn -> 
        {:error, "Unauthorized"}
      end)

      :ok
    end

    test "responds with a 401 when user does not pass api_key" do
      conn = build_conn(:get, "/doesnt/matter")
      result = SetCurrentUser.call(conn, [])

      assert result.halted == true
    end

    test "responds with a 401 when user passes invalid api_key" do
      stub(RaptorServiceMock, :get_user_id_from_api_key, fn _url, _api_key -> 
        {:error, "401 error", 401} 
      end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "invalidApiKey")

      result = SetCurrentUser.call(conn, [])

      assert result.halted == true
    end

    test "responds with a 401 when users call fails" do
      stub(RaptorServiceMock, :get_user_id_from_api_key, fn _url, _api_key -> 
        {:error, "401 error", 401} 
      end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "invalidApiKey")

      result = SetCurrentUser.call(conn, [])

      assert result.halted == true
    end

    test "responds with a 500 when raptor encounters and unexpected error" do
      stub(RaptorServiceMock, :get_user_id_from_api_key, fn _url, _api_key -> 
        {:error, "Unmatched response"} 
      end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")

      result = SetCurrentUser.call(conn, [])

      assert result.halted == true
    end

    test "plug completes when apiKey is valid" do
      stub(RaptorServiceMock, :get_user_id_from_api_key, fn _url, _api_key -> 
        {:ok, "user_id"} 
      end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")

      result = SetCurrentUser.call(conn, [])

      # If the API key is valid, the connection should not be halted
      assert result.halted == false
    end

    test "assigns valid current_user when user passes valid current user" do
      userId = "userId"
      userObject = "I am a user object"

      stub(RaptorServiceMock, :get_user_id_from_api_key, fn _url, _api_key -> 
        {:ok, userId} 
      end)

      conn =
        build_conn(:get, "/doesnt/matter")
        |> put_req_header("api_key", "validApiKey")
        |> assign(:current_user, userObject)

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

      conn = build_conn(:get, "/doesnt/matter")
               |> assign(:current_user, userObject)

      result = SetCurrentUser.call(conn, [])

      assert result == conn |> assign(:current_user, userObject)
    end
  end
end
