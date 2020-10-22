defmodule AndiWeb.Auth.TokenHandler do
  @moduledoc """
  Token handling specific to Andi.
  """

  use Auth.Guardian.TokenHandler,
    otp_app: :andi

  @doc """
  Puts a JWT into a Plug.Session cookie
  """
  def put_session_token(conn, token) do
    TelemetryEvent.add_event_metrics([app: "andi"], [:andi_login_success])
    Guardian.Plug.put_session_token(conn, token)
  end

  @doc """
  Clears the user's token from their session (which revokes it) and logs them out of Auth0
  """
  def log_out(conn) do
    andi_log_in_url = log_in_url(conn)
    auth0_client_id = client_id()
    auth0_base_url = config(:issuer)
    auth0_log_out_url = "#{auth0_base_url}v2/logout?returnTo=#{andi_log_in_url}&client_id=#{auth0_client_id}"

    conn = __MODULE__.Plug.sign_out(conn)
    |> Phoenix.Controller.redirect(external: auth0_log_out_url)

    TelemetryEvent.add_event_metrics([app: "andi"], [:andi_logout_success])

    conn
  end

  @doc """
  Determines the subject for a token based on a resource that was previously loaded and the actual token claims.
  """
  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  @doc """
  Given the claims loads a resource (user or otherwise) from a database or separate service to fill out the resource details, such as email, name, etc.
  """
  def resource_from_claims(claims) do
    user_id =
      case Andi.Schemas.User.get_by_subject_id(claims["sub"]) do
        nil -> nil
        user -> user.id
      end

    roles = claims["https://andi.smartcolumbusos.com/roles"] || []
    is_curator = "Curator" in roles

    {:ok, %{"user_id" => user_id, "roles" => roles, "is_curator" => is_curator}}
  end

  defp log_in_url(conn) do
    AndiWeb.Router.Helpers.url(conn) <> "/auth/auth0"
  end

  defp client_id() do
    ueberauth_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)

    Keyword.fetch!(ueberauth_config, :client_id)
  end
end
