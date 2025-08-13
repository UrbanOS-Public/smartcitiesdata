defmodule DiscoveryApi.Services.AuthServiceTest do
  use ExUnit.Case
  import Mox
  
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Services.AuthService
  alias Auth.TestHelper

  setup :verify_on_exit!
  setup :set_mox_from_context

  @instance_name DiscoveryApi.instance_name()

  setup do
    # Set up a simple mock bypass for testing without actual HTTP server
    bypass = %{port: 9999}  # Mock bypass object
    
    # Configure application for testing with mock endpoint
    original_config = Application.get_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler)
    Application.put_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler, 
      issuer: "http://localhost:#{bypass.port}/"
    )
    
    Brook.Test.register(@instance_name)
    
    # Set up mocks using :meck (Guardian.Plug is already mocked globally)
    try do
      :meck.new(HTTPoison, [:passthrough]) 
    catch
      :error, {:already_started, _} -> :ok
    end

    try do
      :meck.new(SmartCity.User, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end

    try do
      :meck.new(Brook.Event, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end

    try do
      :meck.new(Users, [:passthrough])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    on_exit(fn ->
      # Restore original config
      Application.put_env(:discovery_api, DiscoveryApiWeb.Auth.TokenHandler, original_config)
      
      # Clean up meck modules (except Guardian.Plug which is managed globally)
      try do
        :meck.unload(HTTPoison)
        :meck.unload(SmartCity.User)
        :meck.unload(Brook.Event)
        :meck.unload(Users)
      catch
        :error, _ -> :ok
      end
    end)
    
    # Create mock connections without actual Bypass server
    conn = Phoenix.ConnTest.build_conn()
    authorized_conn = Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{TestHelper.valid_jwt()}")
      |> Plug.Conn.put_req_header("content-type", "application/json")
    
    %{
      bypass: bypass,
      conn: conn, 
      authorized_conn: authorized_conn,
      authorized_token: TestHelper.valid_jwt()
    }
  end

  describe "auth service test" do
    test "returns unauthorized error for invalid bearer token", %{authorized_conn: conn} do
      # Mock HTTPoison to return server error  
      :meck.expect(HTTPoison, :get, fn _url, _headers ->
        {:ok, %{body: Jason.encode!(%{body: %{"error" => "error"}}), status_code: 500}}
      end)

      :meck.expect(Guardian.Plug, :current_token, fn _conn -> "bad token" end)

      {:error, reason} = AuthService.create_logged_in_user(conn)

      assert reason == "Unauthorized"
    end

    test "returns internal server error when user info cannot be parsed", %{authorized_conn: conn} do
      # Mock HTTPoison to return invalid JSON
      :meck.expect(HTTPoison, :get, fn _url, _headers ->
        {:ok, %{body: "this is not user info... it's not even json", status_code: 200}}
      end)

      :meck.expect(Guardian.Plug, :current_token, fn _conn -> "valid_token" end)

      {:error, reason} = AuthService.create_logged_in_user(conn)

      assert reason == "Internal Server Error"
    end

    test "returns internal server error when user cannot be saved", %{authorized_conn: conn} do
      # Mock HTTPoison to return valid user info
      :meck.expect(HTTPoison, :get, fn _url, _headers ->
        {:ok, %{body: Jason.encode!(%{"email" => "x@y.z", "name" => "xyz"}), status_code: 200}}
      end)

      :meck.expect(Guardian.Plug, :current_token, fn _conn -> "valid_token" end)
      :meck.expect(Guardian.Plug, :current_claims, fn _conn -> %{"sub" => "testUserName"} end)
      :meck.expect(Users, :create_or_update, fn "testUserName", %{email: "x@y.z", name: "xyz"} -> "Unknown Error" end)

      {:error, reason} = AuthService.create_logged_in_user(conn)

      assert reason == "Internal Server Error"
    end

    test "returns updated conn and saves user data on success", %{authorized_conn: authorized_conn, authorized_token: _token} do
      subject = "testUserName"
      smart_user = "smrtUser"
      test_user = "testUser"
      email = "x@y.z"
      name = "xyz"

      # Mock HTTPoison to return valid user info
      :meck.expect(HTTPoison, :get, fn _url, headers ->
        # Verify authorization header is passed correctly
        assert headers == [{"Authorization", "Bearer valid_token"}]
        {:ok, %{body: Jason.encode!(%{"email" => email, "name" => name}), status_code: 200}}
      end)

      :meck.expect(Guardian.Plug, :current_token, fn _conn -> "valid_token" end)
      :meck.expect(Guardian.Plug, :current_claims, fn _conn -> %{"sub" => subject} end)
      :meck.expect(Guardian.Plug, :put_current_resource, fn conn, user -> 
        # Return the same conn with user assigned (simplified for testing)
        %{conn | assigns: Map.put(conn.assigns, :current_resource, user)}
      end)
      :meck.expect(Users, :create_or_update, fn ^subject, %{email: ^email, name: ^name} -> {:ok, test_user} end)
      :meck.expect(SmartCity.User, :new, fn %{subject_id: ^subject, email: ^email, name: ^name} -> {:ok, smart_user} end)
      :meck.expect(Brook.Event, :send, fn @instance_name, _event_type, _module, ^smart_user -> :ok end)

      {:ok, new_conn} = AuthService.create_logged_in_user(authorized_conn)

      # Verify the conn has the user resource assigned
      assert new_conn.assigns[:current_resource] == test_user
    end
  end
end
