defmodule AndiWeb.Plugs.APIRequireCurator do
  @moduledoc """
  Convenience plug to verify the provided APIKey has the Curator role
  """
  use Properties, otp_app: :andi
  require Logger

  getter(:raptor_url, generic: true)

  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    if System.get_env("REQUIRE_ADMIN_API_KEY") == "true" do
      api_key = get_api_key_from_header(conn)

      if api_key == "" || api_key == nil do
        render_401_missing_api_key(conn)
      else
        url = raptor_url()

        case RaptorService.check_auth0_role(url, get_api_key_from_header(conn), "Curator") do
          {:ok, true} ->
            conn

          {:ok, false} ->
            Logger.error("Rejected api endpoint request due to missing role for api key: #{api_key}")
            render_401_missing_role(conn)

          {:error, error_reason, status_code} when status_code == 401 ->
            Logger.error("Raptor reported unauthorized api_key with reason: #{inspect(error_reason)}")
            render_401_missing_api_key(conn)

          {:error, error_reason, status_code} ->
            Logger.error("Error when checking auth0 role via raptor: #{inspect(error_reason)}")
            render_500_internal_server_error(conn)
        end
      end
    else
      conn
    end
  end

  defp render_401_missing_api_key(conn) do
    conn
    |> send_resp(401, "Unauthorized: Invalid header api_key")
    |> halt
  end

  defp render_401_missing_role(conn) do
    conn
    |> send_resp(401, "Unauthorized: Missing user role")
    |> halt
  end

  defp render_500_internal_server_error(conn) do
    conn
    |> send_resp(500, "Internal Server Error")
    |> halt
  end

  defp get_api_key_from_header(conn) do
    get_req_header(conn, "api_key") |> List.first()
  end
end
