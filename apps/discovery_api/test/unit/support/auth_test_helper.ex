defmodule DiscoveryApiWeb.Test.AuthTestHelper do
  @moduledoc """
  Helper functions for handling authentication in unit tests
  """
  
  def setup_test_auth() do
    # Override Guardian modules with test versions
    Application.put_env(:discovery_api, :test_mode, true)
    
    # Mock Guardian modules at the module level
    :meck.new(Guardian.Plug, [:passthrough])
    :meck.new(Auth.Guardian.Plug.VerifyHeader, [:passthrough])
    
    # Override specific Guardian functions to use test implementations
    :meck.expect(Guardian.Plug, :current_resource, fn conn ->
      DiscoveryApiWeb.Test.TestGuardian.current_resource(conn)
    end)
    
    # Override the Guardian plugs with test implementations
    :meck.expect(Auth.Guardian.Plug.VerifyHeader, :call, fn conn, _opts -> conn end)
    
    :ok
  end
  
  def cleanup_test_auth() do
    :meck.unload(Guardian.Plug)
    :meck.unload(Auth.Guardian.Plug.VerifyHeader)
    Application.put_env(:discovery_api, :test_mode, false)
    :ok
  end
  
  def assign_test_user(conn, user_attrs \\ %{}) do
    default_user = %{
      id: "test_user_id",
      email: "test@example.com",
      organizations: []
    }
    
    user = Map.merge(default_user, user_attrs)
    Plug.Conn.assign(conn, :current_user, user)
  end
  
  def assign_test_user_with_org(conn, org_id) do
    user = %{
      id: "test_user_id",
      email: "test@example.com", 
      organizations: [%{id: org_id}]
    }
    
    Plug.Conn.assign(conn, :current_user, user)
  end
end