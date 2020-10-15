defmodule DiscoveryApiWeb.Plugs.VerifyHeaderAuth0 do
  @moduledoc """
  Wraps Guardian's VerifyHeader plug to allow retries when verification fails on a cached JWKS.
  """
  require Logger
  alias Auth.Auth0.CachedJWKS

  def init(default) do
    Guardian.Plug.VerifyHeader.init(default)
  end

  def call(conn, opts) do
    result = Guardian.Plug.VerifyHeader.call(conn, opts)

    if verification_failed?(result) do
      Logger.info("Unable to verify auth headers\n\nClearing cache and retrying...")
      CachedJWKS.clear()
      # VerifyHeader will refresh the jwks if possible
      Guardian.Plug.VerifyHeader.call(conn, opts)
    else
      result
    end
  end

  defp verification_failed?(conn) do
    !Guardian.Plug.current_token(conn)
  end
end
