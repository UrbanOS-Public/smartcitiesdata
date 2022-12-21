defmodule DiscoveryApiWeb.UserController do
  require Logger
  use DiscoveryApiWeb, :controller

  import SmartCity.Event, only: [user_login: 0]
  alias DiscoveryApi.Services.AuthService
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApiWeb.Auth.TokenHandler

  @instance_name DiscoveryApi.instance_name()

  def logged_in(conn, _params) do
    case AuthService.create_logged_in_user(conn) do
      {:ok, new_conn} -> new_conn |> send_resp(:ok, "")
      error ->
        Logger.error("Unable to handle user logged_in: #{inspect(error)}")
        render_error(conn, 500, "Internal Server Error")
    end
  end

  def logged_out(conn, _params) do
    TokenHandler.Plug.sign_out(conn)
    |> send_resp(:ok, "")
  end
end
