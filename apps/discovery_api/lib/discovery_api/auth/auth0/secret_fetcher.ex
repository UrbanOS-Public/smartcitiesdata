defmodule DiscoveryApi.Auth.Auth0.SecretFetcher do
  @moduledoc """
  Fetches and caches the JWKS (JSON Web Key Set) from Auth0.
  The JWKS is used to create the secret key needed to decode and validate JWTs (tokens from Auth0).
  """
  use Guardian.Token.Jwt.SecretFetcher

  alias DiscoveryApi.Services.AuthService

  def fetch_verifying_secret(_module, token_headers, _opts) do
    %{"kid" => key_id} = token_headers

    get_key(key_id)
  end

  defp get_key(key_id) do
    case cached_jwks() |> key_from_jwks(key_id) do
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
    case AuthService.get_jwks() do
      {:ok, jwks} ->
        Application.put_env(:discovery_api, :jwks_cache, jwks)
        jwks

      error ->
        error
    end
  end

  defp cached_jwks() do
    Application.get_env(:discovery_api, :jwks_cache)
  end
end
