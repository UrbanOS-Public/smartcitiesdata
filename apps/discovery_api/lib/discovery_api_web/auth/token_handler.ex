defmodule DiscoveryApiWeb.Auth.TokenHandler do
  @moduledoc """
  A module that hooks into Guardian's token lifecycle in order to provide extra verifications.
  Primarily, this module introduces Guardian.DB for token revocation purposes.

  Major differences with usual Guardian.DB implementation:
  - we don't generate the token in the API
  - we only track revoked tokes, not ALL tokens
  - verification in this case checks if the token has been revoked, not that it exists in the DB
  """

  use Guardian, otp_app: :discovery_api

  alias DiscoveryApi.Schemas.Users
  require Logger

  @token_type "JWT"

  def subject_for_token(resource, _claims) do
    {:ok, resource}
  end

  def resource_from_claims(claims) do
    Users.get_user_with_organizations(claims["sub"], :subject_id)
  end

  def after_encode_and_sign(_resource, _claims, token, _options) do
    {:ok, token}
  end

  def on_verify(claims, _token, _options) do
    case claims_revoked?(claims) do
      false -> {:ok, claims}
      true -> {:error, :invalid_token}
    end
  rescue
    e -> {:error, e}
  end

  def on_revoke(claims, token, _options) do
    revoke_claims(claims, token)
  rescue
    e -> {:error, e}
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    {:ok, {old_token, old_claims}, {new_token, new_claims}}
  end

  defp claims_revoked?(claims) do
    revoked_claims = to_revoked_claims(claims)

    case Guardian.DB.Token.find_by_claims(revoked_claims) do
      nil -> false
      _ -> true
    end
  end

  defp revoke_claims(claims, token) do
    revoked_claims = to_revoked_claims(claims)

    case Guardian.DB.Token.create(revoked_claims, token) do
      {:ok, _} -> {:ok, claims}
      _ -> {:error, :failed_to_revoke_claims}
    end
  end

  defp claims_to_jwtid(claims) do
    claims
    |> Jason.encode!()
    |> hash()
  end

  def to_revoked_claims(claims) do
    jwtid = claims
    |> Map.put("revoked", true)
    |> claims_to_jwtid()

    claims
    |> Map.put("typ", @token_type)
    |> Map.put("jti", jwtid)
    |> Map.update("aud", "", &Enum.join(&1, " "))
  end

  defp hash(hashable) do
    :crypto.hash(:sha256, hashable)
    |> Base.encode16()
  end
end
