defmodule Auth.Auth0.CachedJWKS.Behaviour do
  @callback key_from_jwks({:ok, map()} | {:error, any()}, String.t()) :: {:ok, any()} | {:error, String.t()}
  @callback get(String.t()) :: {:ok, map()} | {:error, any()}
  @callback clear() :: :ok
end