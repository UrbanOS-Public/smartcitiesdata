defmodule Auth.Auth0.SecretFetcher do
  @moduledoc false

  use Guardian.Token.Jwt.SecretFetcher
  @behaviour Auth.Auth0.SecretFetcher.Behaviour


  alias Auth.Auth0.CachedJWKS

  def fetch_verifying_secret(module, token_headers, _opts) do
    %{"kid" => key_id} = token_headers
    issuer = apply(module, :config, [:issuer])

    CachedJWKS.get_key(issuer, key_id)
  end
end
