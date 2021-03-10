defmodule AndiWeb.AuthController do
  @moduledoc """
  Module handles requests to authenticate and authorize
  """
  use AndiWeb, :controller
  require Logger
  plug Ueberauth

  access_levels(
    request: [:private, :public],
    callback: [:private, :public],
    logout: [:private, :public]
  )

  import SmartCity.Event, only: [user_login: 0]
  alias Andi.Schemas.User
  alias AndiWeb.Auth.TokenHandler

  @instance_name Andi.instance_name()

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, params) do
    Logger.error("Failed to retrieve auth credentials: #{inspect(fails)} with params #{inspect(params)}")

    conn
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    {:ok, user} = Andi.Schemas.User.create_or_update(auth.uid, %{email: auth.info.email})
    Brook.Event.send(@instance_name, user_login(), __MODULE__, user)

    conn
    |> TokenHandler.put_session_token(auth.credentials.token)
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    TokenHandler.log_out(conn)
  end
end
