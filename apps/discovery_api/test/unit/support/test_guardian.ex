defmodule DiscoveryApiWeb.Test.TestGuardian do
  @moduledoc """
  Test-only Guardian implementation that bypasses database requirements
  """
  
  def current_resource(conn) do
    # In test mode, return a mock user if current_user is already assigned,
    # otherwise return nil to allow blank users
    Map.get(conn.assigns, :current_user)
  end
  
  def load_resource(conn, opts) do
    # In test mode, ensure we have a resource if current_user is assigned
    # This handles both allow_blank: true and allow_blank: false
    current_user = Map.get(conn.assigns, :current_user)
    allow_blank = Keyword.get(opts, :allow_blank, true)
    
    
    case {current_user, allow_blank} do
      {nil, true} ->
        # Allow blank users when allow_blank: true
        conn
      {nil, false} ->
        # Fail when allow_blank: false and no user
        conn
        |> DiscoveryApiWeb.RenderError.render_error(401, "Unauthorized")
        |> Plug.Conn.halt()
      {user, _} ->
        # Set the Guardian resource for authenticated users
        Guardian.Plug.put_current_resource(conn, user)
    end
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