defmodule DiscoveryApiWeb.Test.TestGuardian do
  @moduledoc """
  Test-only Guardian implementation that bypasses database requirements
  """
  
  def current_resource(conn) do
    # In test mode, return a mock user if current_user is already assigned,
    # otherwise return nil to allow blank users
    Map.get(conn.assigns, :current_user)
  end
  
  def load_resource(conn, _opts) do
    # In test mode, just pass through the connection unchanged
    # The current_user should be set by test setup if needed
    conn
  end
  
  def verify_header(conn, _opts) do
    # In test mode, skip token verification
    # Tests can manually assign current_user as needed
    conn
  end
  
  def ensure_authenticated(conn, _opts) do
    case Map.get(conn.assigns, :current_user) do
      nil -> 
        conn
        |> DiscoveryApiWeb.RenderError.render_error(401, "Unauthorized")
        |> Plug.Conn.halt()
      _user -> 
        conn
    end
  end
end