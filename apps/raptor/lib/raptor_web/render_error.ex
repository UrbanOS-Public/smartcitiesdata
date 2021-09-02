defmodule RaptorWeb.RenderError do
  @moduledoc false
  import Plug.Conn
  import Phoenix.Controller
  @error_module RaptorWeb.ErrorView
  @error_template :error

  def render_error(conn, status_code, message) when is_binary(message) do
    render_error(conn, status_code, message: message)
  end

  def render_error(conn, status_code, %_struct{} = assigns) do
    render_error(conn, status_code, Map.from_struct(assigns))
  end

  def render_error(conn, status_code, assigns) do
    conn
    |> put_format("json")
    |> put_status(status_code)
    |> put_view(@error_module)
    |> render(@error_template, assigns)
  end
end
