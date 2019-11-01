defmodule AndiWeb.Redirect do
  @moduledoc """
  A Plug to allow for easily doing redirects within a Plug or Phoenix router.

  Based on code found at:
    https://www.viget.com/articles/how-to-redirect-from-the-phoenix-router/
  """
  def init([to: _] = opts), do: opts
  def init(_default), do: raise("Missing required option ':to' in redirect")

  def call(conn, opts) do
    conn
    |> Phoenix.Controller.redirect(opts)
  end
end
