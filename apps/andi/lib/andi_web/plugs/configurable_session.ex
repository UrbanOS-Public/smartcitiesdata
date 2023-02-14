defmodule ConfigurableSession do
  @moduledoc """
  A Plug to allow for configuring Plug.Session at runtime.
  """

  def init(opts), do: Plug.Session.init(opts)

  def call(conn, opts) do
    cookie_opts = Keyword.put(opts.cookie_opts, :secure, Application.get_env(:andi, AndiWeb.Endpoint)[:secure_cookie])
    runtime_opts = %{opts | cookie_opts: cookie_opts}

    Plug.Session.call(conn, runtime_opts)
  end
end
