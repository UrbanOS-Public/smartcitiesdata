defmodule Auth.Auth0.SecretFetcher.Behaviour do
  @callback fetch_verifying_secret(module(), map(), Keyword.t()) :: {:ok, map()} | {:error, any()}
end
