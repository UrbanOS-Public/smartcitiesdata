defmodule Auth.Auth0.JWKS do
  @moduledoc """
  Module to handle JSON Web Key Sets from Auth0.
  """
  require Logger

  @behaviour Auth.Auth0.CachedJWKS.Behaviour

  def get_key(jwks_url, kid) do
    with {:ok, jwks} <- get(jwks_url) do
      key_from_jwks(jwks, kid)
    end
  end

  def key_from_jwks(jwks, kid) do
    Logger.debug("Finding key for #{kid} in JWKS")

    case JOSE.JWK.from_map(jwks) do
      {:ok, key} ->
        Logger.debug("Found key: #{inspect(key)}")
        {:ok, key}

      {:error, e} ->
        Logger.error("Error parsing JWKS: #{inspect(e)}")
        {:error, e}
    end
  end

  def get(jwks_url) do
    case HTTPoison.get(jwks_url) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.debug("Successfully fetched JWKS")
        Jason.decode(body)

      {:ok, %{status_code: status_code, body: body}} ->
        Logger.error("Error fetching JWKS: #{status_code} #{body}")
        {:error, "Error fetching JWKS: #{status_code} #{body}"}

      {:error, %{reason: reason}} ->
        Logger.error("Error fetching JWKS: #{reason}")
        {:error, "Error fetching JWKS: #{reason}"}
    end
  end

  def clear() do
    :ok
  end
end