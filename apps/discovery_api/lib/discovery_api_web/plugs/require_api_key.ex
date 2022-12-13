defmodule DiscoveryApiWeb.Plugs.RequireApiKey do
  @moduledoc """
  Plug to verify the user's api key
  """

  require Logger
  import Plug.Conn

  alias RaptorService

  use Properties, otp_app: :discovery_api

  getter(:raptor_url, generic: true)

  def init(default), do: default

  def call(conn) do
    api_key = get_req_header(conn, "api_key")

    if api_key != [] do
      case RaptorService.is_valid_api_key(raptor_url(), api_key) do
        true -> conn
        _ -> render_401_invalid_api_key(conn)
      end
    else
      render_401_missing_api_key(conn)
    end
  end

  defp render_401_missing_api_key(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(401, "Unauthorized: required header api_key not present")
    |> halt()
  end

  defp render_401_invalid_api_key(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(401, "Unauthorized: invalid api_key")
    |> halt()
  end
end
