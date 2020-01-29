defmodule DiscoveryApiWeb.Plugs.Restrictor do
  @moduledoc false
  require Logger
  import Plug.Conn
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  def init(default), do: default

  def call(conn, _) do
    user = conn.assigns.current_user

    case ModelAccessUtils.has_access?(conn.assigns.model, user) do
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
