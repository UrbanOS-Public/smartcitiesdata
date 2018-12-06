defmodule DiscoveryApiWeb.Renderer do
  use DiscoveryApiWeb, :controller

  def render_500(conn, reason) do
    conn
    |> put_status(:internal_server_error)
    |> render(DiscoveryApiWeb.ErrorView, :"500", message: reason)
  end
end
