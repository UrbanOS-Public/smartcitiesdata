defmodule DiscoveryApiWeb.Plugs.Restrictor do
  @moduledoc """
    Authorizes access to requested dataset
  """
  require Logger
  import Plug.Conn
  alias DiscoveryApiWeb.Services.AuthService

  def init(default), do: default

  def call(conn, _) do
    username = AuthService.get_user(conn)

    case AuthService.has_access?(conn.assigns.model, username) do
      true -> conn
      _ -> handle_unauthorized(conn)
    end
  end

  defp handle_unauthorized(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
    |> halt()
  end
end
