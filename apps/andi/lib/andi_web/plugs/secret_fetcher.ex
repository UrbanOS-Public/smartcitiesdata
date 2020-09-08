defmodule Andi.Auth.Auth0.SecretFetcher do
  @moduledoc false

  use Guardian.Token.Jwt.SecretFetcher

  alias Andi.Services.AuthService
  alias Andi.Auth.Auth0.CachedJWKS

  def fetch_verifying_secret(_module, token_headers, _opts) do
    token_headers |> IO.inspect(label: "fetch secret")
    %{"kid" => key_id} = token_headers

    get_key(key_id)
  end

  defp get_key(key_id) do
    case CachedJWKS.get() |> IO.inspect(label: "cached") |> key_from_jwks(key_id) |> IO.inspect(label: "key from jwks") do
      {:error, _} -> fetch_and_cache_jwks() |> key_from_jwks(key_id)
      result -> result
    end
  end

  defp key_from_jwks(nil, _key_id), do: {:error, :jwks_unavailable}

  defp key_from_jwks({:error, _reason} = error, _key_id), do: error

  defp key_from_jwks(jwks, key_id) do
    key =
      jwks
      |> Map.get("keys")
      |> Enum.find(fn key -> Map.get(key, "kid") == key_id end)

    case key do
      nil -> {:error, "no key for kid: #{key_id}"}
      key -> {:ok, JOSE.JWK.from(key)}
    end
  end

  defp fetch_and_cache_jwks() do
    case AuthService.get_jwks() |> IO.inspect(label: "JWKS") do
      {:ok, jwks} ->
        CachedJWKS.set(jwks)
        jwks

      error ->
        error
    end
  end
end
