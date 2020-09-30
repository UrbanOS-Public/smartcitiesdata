defmodule AndiWeb.Auth.ErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, error, _opts) do
    Logger.error("Auth failed: #{inspect(error)}")

    error_message =
      "Unauthorized"
      |> Jason.encode!()

    Phoenix.Controller.redirect(conn, to: "/auth/auth0?prompt=login&error_message=Unauthorized")
  end
end
