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
  Determines the subject for a token based on a resource that was previously loaded and the actual token claims.
  """
  def subject_for_token(resource, _claims) do
    IO.inspect(resource, label: "actually here?")
    {:ok, resource}
  end

  @doc """
  Given the claims loads a resource (user or otherwise) from a database or separate service to fill out the resource details, such as email, name, etc.
  """
  def resource_from_claims(claims) do
    IO.inspect(claims, label: "actually here?")
    {:ok, claims["sub"]}
  end
end
