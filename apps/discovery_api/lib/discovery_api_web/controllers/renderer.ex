defmodule DiscoveryApiWeb.Renderer do
  use DiscoveryApiWeb, :controller

  def render_500(conn, reason) do
    conn
    |> put_status(:internal_server_error)
    |> render(DiscoveryApiWeb.ErrorView, :"500", message: reason)
  end

  def render_400(conn, reason) do
    conn
    |> put_status(400)
    |> render(DiscoveryApiWeb.ErrorView, :"400", message: reason)
  end
end
