defmodule AndiWeb.Auth.ErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {:unauthenticated, "https://andi.smartcolumbusos.com/roles"}, _opts) do
    Logger.error("Auth failed: user does not have authorized role")

    TelemetryEvent.add_event_metrics([app: "andi"], [:andi_login_failure])

    Phoenix.Controller.redirect(conn, to: "/auth/auth0?prompt=login&error_message=Unauthorized")
  end

  def auth_error(conn, error, _opts) do
    Logger.error("Auth failed: #{inspect(error)}")

    TelemetryEvent.add_event_metrics([app: "andi"], [:andi_login_failure])

    Phoenix.Controller.redirect(conn, to: "/auth/auth0?prompt=login")
  end
end
