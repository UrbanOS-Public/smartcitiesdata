defmodule DiscoveryApiWeb.UserController do
  require Logger
  use DiscoveryApiWeb, :controller

  import SmartCity.Event, only: [user_login: 0]
  alias DiscoveryApi.Services.AuthService
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApiWeb.Auth.TokenHandler

  @instance_name DiscoveryApi.instance_name()

  def logged_in(conn, _params) do
    with {:ok, user_info} <- AuthService.get_user_info(Guardian.Plug.current_token(conn)),
         {:ok, email} <- Map.fetch(user_info, "email"),
         {:ok, name} <- Map.fetch(user_info, "name"),
         subject_id <- Guardian.Plug.current_claims(conn)["sub"],
         {:ok, _user} <- Users.create_or_update(subject_id, %{email: email, name: name}) do
      {:ok, smrt_user} = SmartCity.User.new(%{subject_id: subject_id, email: email, name: name})
      Brook.Event.send(@instance_name, user_login(), __MODULE__, smrt_user)
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
