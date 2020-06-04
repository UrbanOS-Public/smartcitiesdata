defmodule DiscoveryApiWeb.AuthTokens.Guardian do
  @moduledoc """
  A module providing TBD
  """
  use Guardian, otp_app: :discovery_api

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    Users.get_user_with_organizations(claims["sub"], :subject_id)
  end

  def after_encode_and_sign(_resource, _claims, token, _options) do
    {:ok, token}
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    {:ok, {old_token, old_claims}, {new_token, new_claims}}
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end
end
