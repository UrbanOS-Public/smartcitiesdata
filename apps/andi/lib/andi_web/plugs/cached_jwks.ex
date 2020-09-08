defmodule Andi.Auth.Auth0.CachedJWKS do
  @moduledoc """
  Wrapper for cached JWKS in Application ENV.
  """
  def get() do
    Application.get_env(:andi, :jwks_cache)
  end

  def set(jwks) do
    Application.put_env(:andi, :jwks_cache, jwks)
  end

  def delete() do
    Application.delete_env(:andi, :jwks_cache)
  end
end
