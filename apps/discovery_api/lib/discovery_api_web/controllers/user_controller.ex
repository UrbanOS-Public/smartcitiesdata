defmodule DiscoveryApiWeb.UserController do
  require Logger
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Services.AuthService
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApiWeb.Auth.TokenHandler

  def logged_in(conn, _params) do
    with {:ok, user_info} <- AuthService.get_user_info(Guardian.Plug.current_token(conn)),
         {:ok, email} <- Map.fetch(user_info, "email"),
         subject_id <- Guardian.Plug.current_claims(conn)["sub"],
         {:ok, _user} <- Users.create_or_update(subject_id, %{email: email}) do
      conn |> send_resp(:ok, "")
    else
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
