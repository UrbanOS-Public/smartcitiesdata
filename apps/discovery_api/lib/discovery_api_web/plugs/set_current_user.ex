defmodule DiscoveryApiWeb.Plugs.SetCurrentUser do
  @moduledoc """
  Convenience plug to set current user on connection - basically aliasing loaded resource
  """

  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    current_user = DiscoveryApiWeb.AuthTokens.Guardian.Plug.current_resource(conn)
    assign(conn, :current_user, current_user)
  end
end
