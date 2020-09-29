defmodule Auth.Auth0.SecretFetcher do
  @moduledoc false

  use Guardian.Token.Jwt.SecretFetcher

  alias Auth.Auth0.CachedJWKS

  def fetch_verifying_secret(_module, token_headers, opts) do
    %{"kid" => key_id} = token_headers
    issuer = Keyword.get(opts, :issuer)

    CachedJWKS.get_key(issuer, key_id)
  end

  # defp fetch_and_cache_jwks() do
  #   case AuthService.get_jwks() do
  #     {:ok, jwks} ->
  #       CachedJWKS.set(jwks)
  #       jwks

  #     error ->
  #       error
  #   end
  # end

end
