defmodule DiscoveryApiWeb.Plugs.CookieMonster do
  @moduledoc """
    Eats cookies that do not belong
  """
  require Logger

  def init(default), do: default

  def call(%Plug.Conn{} = conn, _opts) do
    with false <- origin_allowed?(conn),
         true <- cookie_token_exists?(conn) do
      conn
      |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
      |> Plug.Conn.halt()
    else
      _ ->
        conn
    end
  end

  defp origin_allowed?(conn), do: conn.assigns.allowed_origin

  defp cookie_token_exists?(conn) do
    conn
    |> Plug.Conn.get_req_header("cookie")
    |> Enum.join(",")
    |> Plug.Conn.Cookies.decode()
    |> Map.has_key?(Guardian.Plug.Keys.token_key() |> Atom.to_string())
  end
end
