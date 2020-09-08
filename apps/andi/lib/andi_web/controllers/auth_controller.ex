defmodule AndiWeb.AuthController do
  @moduledoc """
  Module handles requests to authenticate and authorize
  """
  use AndiWeb, :controller
  plug Ueberauth
  alias Ueberauth.Strategy.Helpers

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    IO.inspect(fails, label: "failure")
    conn
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
    token = auth.credentials.token

    conn
    |> Plug.Conn.fetch_session()
    |> AndiWeb.Auth.TokenHandler.Plug.put_session_token(token)
    |> redirect(to: "/")
  end
end
