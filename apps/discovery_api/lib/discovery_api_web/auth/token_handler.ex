defmodule DiscoveryApiWeb.Auth.TokenHandler do
  @moduledoc """
  A module that hooks into Guardian's token lifecycle in order to provide extra verifications.
  Primarily, this module introduces Guardian.DB for token revocation purposes.

  Major differences with usual Guardian.DB implementation:
  - we don't generate the token in the API
  - because we don't generate the token, we need a way to put a token in the DB
  - because Guardian.DB thinks "in the DB" = "not revoked" we need a way of gating the process to put a token in the DB
  - for this we create a revoke marker (just a token) for `on_revoke` and check that on `on_verify + store`
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

  def after_encode_and_sign(resource, claims, token, _options) do
    storable_claims = to_storable_claims(claims)

    case Guardian.DB.after_encode_and_sign(resource, @token_type, storable_claims, token) do
      {:ok, _} -> {:ok, token}
      e -> e
    end
  rescue
    e -> {:error, e}
  end

  def on_verify(claims, token, options) do
    case Keyword.get(options, :store_token, false) do
      true -> store_and_verify(claims, token, options)
      false -> verify(claims, token, options)
    end
  rescue
    e -> {:error, e}
  end

  def on_revoke(claims, token, _options) do
    case revoke_claims(claims, token) do
      {:ok, _} -> delete_claims(claims, token)
    end
  rescue
    e -> {:error, e}
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    {:ok, {old_token, old_claims}, {new_token, new_claims}}
  end

  defp verify(claims, token, _options) do
    storable_claims = to_storable_claims(claims)

    case Guardian.DB.on_verify(storable_claims, token) do
      {:ok, _} -> {:ok, claims}
      e -> e
    end
  end

  defp store_and_verify(claims, token, _options) do
    case claims_revoked?(claims) do
      false -> ensure_claims(claims, token)
      true -> {:error, :invalid_token}
    end
  end

  defp claims_revoked?(claims) do
    revoked_claims = to_revoked_claims(claims)

    case Guardian.DB.Token.find_by_claims(revoked_claims) do
      nil -> false
      _ -> true
    end
  end

  defp ensure_claims(claims, token) do
    verify(claims, token, [])
    |> handle_verify_result(claims, token)
  end

  defp handle_verify_result({:ok, _} = good, _c, _t), do: good

  defp handle_verify_result({:error, :token_not_found}, claims, token) do
    case after_encode_and_sign(:na, claims, token, []) do
      {:ok, _} -> verify(claims, token, [])
      _ -> {:error, :invalid_token}
    end
  end

  defp handle_verify_result(_, _c, _t), do: {:error, :invalid_token}

  defp revoke_claims(claims, token) do
    revoked_claims = to_revoked_claims(claims)

    case Guardian.DB.Token.create(revoked_claims, token) do
      {:ok, _} -> {:ok, claims}
      _ -> {:error, :failed_to_revoke_claims}
    end
  end

  defp delete_claims(claims, token) do
    storable_claims = to_storable_claims(claims)

    case Guardian.DB.on_revoke(storable_claims, token) do
      {:ok, _} -> {:ok, claims}
      _ -> {:error, :failed_to_delete_claims}
    end
  end

  def claims_to_jwtid(claims) do
    claims
    |> Jason.encode!()
    |> hash()
  end

  def to_revoked_claims(claims) do
    claims
    |> Map.put("revoked", true)
    |> to_storable_claims()
  end

  def to_storable_claims(claims) do
    jwtid = claims_to_jwtid(claims)

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
