defmodule AndiWeb.AuthController do
  @moduledoc """
  Module handles requests to authenticate and authorize
  """
  use AndiWeb, :controller
  require Logger
  plug Ueberauth

  alias AndiWeb.Auth.TokenHandler

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, params) do
    Logger.error("Failed to retrieve auth credentials: #{inspect(fails)} with params #{inspect(params)}")

    conn
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    {:ok, user} = Andi.Schemas.User.create_or_update(auth.uid, %{email: auth.info.email})
    conn
    |> TokenHandler.put_session_token(auth.credentials.token)
    |> Plug.Conn.put_session(:user_id, user.id)
    |> redirect(to: "/")
  end
end
