defmodule AndiWeb.Auth.TokenHandler do
  @moduledoc false

  use Guardian, otp_app: :andi, secret_fetcher: Auth.Auth0.SecretFetcher

  def put_session_token(conn, token) do
    TelemetryEvent.add_event_metrics([app: "andi"], [:andi_login_success])
    Guardian.Plug.put_session_token(conn, token)
  end

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    {:ok, %{"resource" => claims["sub"]}}
  end
end
