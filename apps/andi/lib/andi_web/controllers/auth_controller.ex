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

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        IO.inspect(user, label: "user")
        conn
        |> redirect(to: "/")
      {:error, reason} ->
        IO.inspect(reason, label: "reason")
        conn
        |> redirect(to: "/")
    end
  end
end
