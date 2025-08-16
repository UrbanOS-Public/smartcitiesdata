defmodule DiscoveryApiWeb.UserControllerTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  alias Auth.TestHelper

  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    # Create authenticated connection following successful pattern from data_controller_restricted_test.exs
    conn = build_conn()
    authorized_conn = build_conn()
      |> put_req_header("authorization", "Bearer #{TestHelper.valid_jwt()}")
      |> put_req_header("content-type", "application/json")
    
    %{conn: conn, authorized_conn: authorized_conn}
  end

  describe "POST /logged-in" do
    test "returns 200 when no errors", %{authorized_conn: conn} do
      # Add current_user to conn assigns for TestGuardian authentication
      conn = Plug.Conn.assign(conn, :current_user, %{id: "test_user_id"})
      
      # Mock AuthService using :meck since it doesn't have dependency injection
      try do
        :meck.unload(DiscoveryApi.Services.AuthService)
      catch
        _, _ -> :ok
      end
      
      :meck.new(DiscoveryApi.Services.AuthService, [:non_strict])
      :meck.expect(DiscoveryApi.Services.AuthService, :create_logged_in_user, fn _conn -> {:ok, conn} end)

      response_body =
        conn
        |> post("/api/v1/logged-in")
        |> response(200)

      assert response_body == ""
      
      # Cleanup
      try do
        :meck.unload(DiscoveryApi.Services.AuthService)
      catch
        _, _ -> :ok
      end
    end

    test "returns 500 Internal Server Error create call fails", %{authorized_conn: conn} do
      # Add current_user to conn assigns for TestGuardian authentication
      conn = Plug.Conn.assign(conn, :current_user, %{id: "test_user_id"})
      
      # Mock AuthService using :meck since it doesn't have dependency injection  
      try do
        :meck.unload(DiscoveryApi.Services.AuthService)
      catch
        _, _ -> :ok
      end
      
      :meck.new(DiscoveryApi.Services.AuthService, [:non_strict])
      :meck.expect(DiscoveryApi.Services.AuthService, :create_logged_in_user, fn _conn -> {:error, "error"} end)

      response_body =
        conn
        |> post("/api/v1/logged-in")
        |> json_response(500)

      assert response_body == %{"message" => "Internal Server Error"}
      
      # Cleanup
      try do
        :meck.unload(DiscoveryApi.Services.AuthService)
      catch
        _, _ -> :ok
      end
    end
  end
end
