defmodule AndiWeb.Plugs.APIRequireCurator do
  @moduledoc """
  Convenience plug to verify the provided APIKey has the Curator role
  """
  use Properties, otp_app: :andi

  getter(:raptor_url, generic: true)

  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    if System.get_env("REQUIRE_API_KEY") == "true" do
      api_key = get_api_key_from_header(conn)

      if api_key == "" || api_key == nil do
        render_401_missing_api_key(conn)
      else
        case RaptorService.check_auth0_role(raptor_url(), get_api_key_from_header(conn), "Curator") do
          {:ok, true} -> conn
          {:ok, false} -> render_401_missing_role(conn)
          {:error, error_reason, status_code} -> render_500_internal_server_error(conn)
        end
      end
    else
      conn
    end
  end

  defp render_401_missing_api_key(conn) do
    conn
    |> send_resp(401, "Unauthorized: required header api_key not present")
  end

  defp render_401_missing_role(conn) do
    conn
    |> send_resp(401, "Unauthorized: Missing user role")
  end

  defp render_500_internal_server_error(conn) do
    conn
    |> send_resp(500, "Internal Server Error")
  end

  defp get_api_key_from_header(conn) do
    get_req_header(conn, "api_key") |> List.first()
  end
end
