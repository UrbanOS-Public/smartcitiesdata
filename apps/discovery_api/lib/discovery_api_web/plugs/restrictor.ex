defmodule DiscoveryApiWeb.Plugs.Restrictor do
  @moduledoc false
  require Logger
  import Plug.Conn
  alias DiscoveryApiWeb.Utilities.LdapAccessUtils

  def init(default), do: default

  def call(conn, _) do
    username = conn.assigns.current_user

    case LdapAccessUtils.has_access?(conn.assigns.model, username) do
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
