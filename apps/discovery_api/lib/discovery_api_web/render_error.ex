defmodule DiscoveryApiWeb.RenderError do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller
  @error_module DiscoveryApiWeb.ErrorView
  @error_template :error

  def render_error(conn, status_code, message) when is_binary(message) do
    render_error(conn, status_code, message: message)
  end

  def render_error(conn, status_code, assigns) do
    conn
    |> put_private(:phoenix_format, "json")
    |> put_status(status_code)
    |> put_view(@error_module)
    |> render(@error_template, assigns)
  end
end
