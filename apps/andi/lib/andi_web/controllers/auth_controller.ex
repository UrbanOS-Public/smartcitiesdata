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
  alias AndiWeb.Auth.TokenHandler

  @instance_name Andi.instance_name()

  def request(conn, params) do
    Logger.info("=== AuthController.request called ===")
    Logger.info("  Request path: #{conn.request_path}")
    Logger.info("  Params: #{inspect(params)}")
    Logger.info("  Query string: #{conn.query_string}")

    # Check Ueberauth configuration
    ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)
    Logger.info("  Ueberauth Auth0 OAuth config present: #{not is_nil(ueberauth_config)}")

    if ueberauth_config do
      Logger.info("  Auth0 domain: #{ueberauth_config[:domain]}")
      Logger.info("  Auth0 client_id present: #{not is_nil(ueberauth_config[:client_id])}")
    end

    Logger.info("  Ueberauth should now redirect to Auth0...")

    # Ueberauth handles the redirect to Auth0 via the plug
    # This action just needs to exist for the route to work
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, params) do
    Logger.error("Ueberauth callback FAILED:")
    Logger.error("  Failures: #{inspect(fails)}")
    Logger.error("  Params: #{inspect(params)}")
    Logger.error("  Failure errors: #{inspect(fails.errors)}")

    conn
    |> redirect(to: "/autherror")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    Logger.info("Ueberauth callback SUCCESS:")
    Logger.info("  UID: #{auth.uid}")
    Logger.info("  Email: #{auth.info.email}")
    Logger.info("  Name: #{auth.info.name}")
    Logger.info("  Token present: #{not is_nil(auth.credentials.token)}")

    {:ok, _user} = Andi.Schemas.User.create_or_update(auth.uid, %{email: auth.info.email, name: auth.info.name})
    {:ok, smrt_user} = SmartCity.User.new(%{subject_id: auth.uid, email: auth.info.email, name: auth.info.name})

    if Andi.private_access?() do
      Brook.Event.send(@instance_name, user_login(), __MODULE__, smrt_user)
    end

    Logger.info("Putting session token and redirecting to /")

    conn
    |> TokenHandler.put_session_token(auth.credentials.token)
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    TokenHandler.log_out(conn)
  end
end
