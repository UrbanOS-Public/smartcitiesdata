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

  def auth_error(conn, error, opts) do
    # Check if this is just "user not logged in" vs a real auth failure
    is_no_token = error == {:no_resource_found, :no_resource_found}

    if is_no_token do
      Logger.info("User not authenticated, redirecting to Auth0 login")
    else
      Logger.error("Auth failed: #{inspect(error)}")
      Logger.error("  Error opts: #{inspect(opts)}")
      Logger.error("  Request path: #{conn.request_path}")
    end

    # Only log detailed config on actual auth failures (not just missing token)
    unless is_no_token do
      # Log Guardian/Ueberauth configuration status
      ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)
      Logger.error("  Ueberauth Auth0 config present: #{not is_nil(ueberauth_config)}")

      if ueberauth_config do
        Logger.error("  Auth0 domain: #{ueberauth_config[:domain]}")
        Logger.error("  Auth0 client_id configured: #{not is_nil(ueberauth_config[:client_id])}")
        Logger.error("  Auth0 client_secret configured: #{not is_nil(ueberauth_config[:client_secret])}")
      end

      guardian_config = Application.get_env(:andi, AndiWeb.Auth.TokenHandler)
      Logger.error("  Guardian TokenHandler config present: #{not is_nil(guardian_config)}")

      if guardian_config do
        Logger.error("  Guardian issuer: #{inspect(guardian_config[:issuer])}")
        Logger.error("  Guardian uses Auth0 JWKS (RS256) - no static secret_key needed")
      end
    end

    TelemetryEvent.add_event_metrics([app: "andi"], [:andi_login_failure])

    redirect_url = "/auth/auth0?prompt=login"
    Logger.info("Redirecting to: #{redirect_url}")

    Phoenix.Controller.redirect(conn, to: redirect_url)
  end
end
