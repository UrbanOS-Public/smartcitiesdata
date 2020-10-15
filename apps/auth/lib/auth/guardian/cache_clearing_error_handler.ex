defmodule Auth.Guardian.CacheClearingErrorHandler do
  @moduledoc """
  Clears the JWKS cache for a token if it is invalid
  """

  alias Auth.Auth0.CachedJWKS

  defmacro __using__(opts) do
    verifier_module = Keyword.fetch!(opts, :verifier_module)

    quote do
      require Logger

      def auth_error(conn, {:invalid_token, reason}, opts) do
        case Keyword.get(opts, :cache_cleared, false) do
          true ->
            auth_error(conn, {:invalid_token__tried_cache_clear, reason}, opts)
            |> Plug.Conn.halt()
          false ->
            Logger.info("Unable to verify auth headers with #{inspect(reason)}\n\nClearing cache and retrying...")
            cache_clear_and_retry(conn, opts)
        end
      end

      defp cache_clear_and_retry(conn, opts) do
        CachedJWKS.clear()

        cleared_opts = Keyword.merge(opts, [cache_cleared: true])

        unquote(verifier_module).call(conn, cleared_opts)
      end
    end
  end
end
