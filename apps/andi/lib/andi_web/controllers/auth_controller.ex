defmodule AndiWeb.AuthController do
  @moduledoc """
  Module handles requests to authenticate and authorize
  """
  use AndiWeb, :controller
  require Logger
  plug Ueberauth

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, params) do
    Logger.error("Failed to retrieve auth credentials: #{inspect(fails)} with params #{inspect(params)}")

    conn
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: _auth}} = conn, _params) do
    conn
    |> redirect(to: "/")
  end
end
