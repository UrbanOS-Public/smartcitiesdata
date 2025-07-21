ExUnit.start()

Mox.defmock(Auth.Auth0.CachedJWKS.Mock, for: Auth.Auth0.CachedJWKS.Behaviour)
Mox.defmock(Auth.Auth0.SecretFetcher.Mock, for: Auth.Auth0.SecretFetcher.Behaviour)
Mox.defmock(HTTPoison.Mock, for: HTTPoison.Behaviour)
Mox.defmock(Guardian.Mock, for: Guardian.Behaviour)

Application.ensure_all_started(:bypass)
