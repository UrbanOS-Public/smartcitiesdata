defmodule Auth.Auth0.SecretFetcher do
  @moduledoc false

  use Guardian.Token.Jwt.SecretFetcher

  alias Auth.Auth0.CachedJWKS

  def fetch_verifying_secret(module, token_headers, opts) do
    %{"kid" => key_id} = token_headers
    # issuer = Keyword.get(opts, :issuer) |> IO.inspect(label: "issuer")
    issuer = apply(module, :config, [:issuer]) |> IO.inspect(label: "issuer")

    CachedJWKS.get_key(issuer, key_id) |> IO.inspect(label: "key")
  end
end
