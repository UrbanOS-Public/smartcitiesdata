defmodule DiscoveryApiWeb.Plugs.CookieMonster do
  @moduledoc """
    Eats cookies that do not belong
  """
  require Logger
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    case validate_cookie(conn, extract_cookie_token(conn)) do
      true -> conn
      _ -> conn |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found") |> halt()
    end
  end

  defp validate_cookie(_conn, nil), do: true
  defp validate_cookie(conn, _cookie), do: origin_allowed_for_cookie_auth?(conn)

  defp origin_allowed_for_cookie_auth?(conn) do
    origin_host_from_request =
      conn
      |> Plug.Conn.get_req_header("origin")
      |> List.first()

    Logger.debug(fn -> "Handling origin: #{origin_host_from_request}" end)

    Application.get_env(:discovery_api, :allowed_origins, [])
    |> Enum.any?(&origin_is_allowed?(&1, origin_host_from_request))
  end

  defp origin_is_allowed?(_allowed_origin, nil), do: true
  defp origin_is_allowed?(_allowed_origin, "null"), do: true
  defp origin_is_allowed?(allowed_origin, origin_host_from_request) when allowed_origin == origin_host_from_request, do: true
  defp origin_is_allowed?(allowed_origin, origin_host_from_request), do: String.ends_with?(origin_host_from_request, ".#{allowed_origin}")

  defp extract_cookie_token(conn) do
    conn
    |> Plug.Conn.get_req_header("cookie")
    |> Enum.join(",")
    |> Plug.Conn.Cookies.decode()
    |> Map.get(Guardian.Plug.Keys.token_key() |> Atom.to_string())
  end
end
