defmodule DiscoveryApiWeb.Plugs.SetCurrentUser do
  @moduledoc """
  Convenience plug to set current user on connection - basically aliasing loaded resource
  """
  use Properties, otp_app: :discovery_api

  getter(:raptor_url, generic: true)
  import Plug.Conn
  alias DiscoveryApi.Schemas.Users
  def init(default), do: default

  def call(conn, _) do
    current_user = Guardian.Plug.current_resource(conn)

    if System.get_env("REQUIRE_API_KEY") == "true" do
      assign_current_user(conn, current_user, get_api_key_from_header(conn))
    else
      assign(conn, :current_user, current_user)
    end
  end

  defp assign_current_user(conn, current_user, api_key) when not is_nil(current_user) do
    assign(conn, :current_user, current_user)
  end

  defp assign_current_user(conn, current_user, api_key) when is_nil(current_user) and is_nil(api_key) do
    render_401_missing_api_key(conn)
  end

  defp assign_current_user(conn, current_user, api_key) when is_nil(current_user) and not is_nil(api_key) do
    case RaptorService.get_user_id_from_api_key(raptor_url(), api_key) do
      {:ok, user_id} ->
        {:ok, user} = Users.get_user(user_id, :subject_id)
        assign(conn, :current_user, user)

      {:error, reason, status_code} when status_code == 401 ->
        render_401_invalid_api_key(conn)

      error ->
        render_500_internal_server_error(conn)
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

  defp render_500_internal_server_error(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(500, "Internal Server Error")
    |> halt()
  end

  defp get_api_key_from_header(conn) do
    get_req_header(conn, "api_key") |> List.first()
  end
end
