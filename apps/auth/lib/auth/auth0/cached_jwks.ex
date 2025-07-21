defmodule Auth.Auth0.CachedJWKS do
  @moduledoc false

  use Memoize
  @behaviour Auth.Auth0.CachedJWKS.Behaviour


  def get(issuer) do
    case HTTPoison.get(issuer <> ".well-known/jwks.json") do
      {:ok, %{body: body}} -> Jason.decode(body)
      error -> error
    end
  end

  defmemo get_key(issuer, key_id) do
    keystore = get(issuer)

    key_from_jwks(keystore, key_id)
  end

  def key_from_jwks({:error, _reason} = error, _key_id), do: error

  def key_from_jwks({:ok, jwks}, key_id) do
    key =
      jwks
      |> Map.get("keys")
      |> Enum.find(fn key -> Map.get(key, "kid") == key_id end)

    case key do
      nil -> {:error, "no key for kid: #{key_id}"}
      key -> {:ok, JOSE.JWK.from(key)}
    end
  end

  def clear() do
    Memoize.invalidate(__MODULE__)
  end

  def clear(issuer, key_id) do
    Memoize.invalidate(__MODULE__, :get_key, [issuer, key_id])
  end
end
