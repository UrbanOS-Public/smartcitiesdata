defmodule DiscoveryApiWeb.UserController do
  require Logger
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Services.AuthService
  alias DiscoveryApi.Schemas.Users

  def logged_in(conn, _params) do
    with {:ok, user_info} <- AuthService.get_user_info(Guardian.Plug.current_token(conn)),
         {:ok, email} <- Map.fetch(user_info, "email"),
         {:ok, _user} <- Users.create_or_update(conn.assigns.current_user, %{email: email}) do
      conn |> send_resp(:ok, "")
    else
      error ->
        Logger.error("Unable to handle user logged_in: #{inspect(error)}")
        render_error(conn, 500, "Internal Server Error")
    end
  end
end
