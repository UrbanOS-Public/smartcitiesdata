defmodule Auth.Auth0.CachedJWKS do
  @moduledoc """
  """

  def get_key(issuer, key_id) do
    {:ok, keystore} =
      case HTTPoison.get(issuer <> "/.well-known/jwks.json") do
        {:ok, %{body: body}} -> Jason.decode(body)
        error -> error
      end

    IO.inspect(keystore, label: "keystore ")
    key_from_jwks(keystore, key_id)
  end

  defp key_from_jwks(nil, _key_id), do: {:error, :jwks_unavailable}

  defp key_from_jwks({:error, _reason} = error, _key_id), do: error

  defp key_from_jwks(jwks, key_id) do
    key =
      jwks
      |> Map.get("keys")
      |> IO.inspect(label: "keys")
      |> Enum.find(fn key -> Map.get(key, "kid") == key_id end)

    case key do
      nil -> {:error, "no key for kid: #{key_id}"}
      key -> {:ok, JOSE.JWK.from(key)}
    end
  end

  def clear() do
    # invalidate the stored value for get
  end
end
