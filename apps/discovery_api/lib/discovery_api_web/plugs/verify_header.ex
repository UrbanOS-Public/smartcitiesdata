defmodule DiscoveryApiWeb.Plugs.VerifyHeader do
  @moduledoc """
  Wraps Guardian's VerifyHeader plug to allow retries when verification fails on a cached JWKS.
  """
  require Logger

  def init(default) do
    Guardian.Plug.VerifyHeader.init(default)
  end

  def call(conn, opts) do
    jwks = Application.get_env(:discovery_api, :jwks_cache)
    result = Guardian.Plug.VerifyHeader.call(conn, opts)

    if verification_failed?(result) and jwks_cached?(jwks) do
      Logger.info("Unable to verify auth headers with a cached JWKS: #{inspect(jwks)}\n\nClearing cache and retrying...")
      Application.delete_env(:discovery_api, :jwks_cache)
      # VerifyHeader will refresh the jwks if possible
      Guardian.Plug.VerifyHeader.call(conn, opts)
    else
      result
    end
  end

  defp verification_failed?(conn) do
    !Guardian.Plug.current_token(conn)
  end

  defp jwks_cached?(jwks) do
    !is_nil(jwks)
  end
end
