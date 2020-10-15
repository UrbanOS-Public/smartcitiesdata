defmodule Auth.Guardian.Plug.VerifySession do
  @moduledoc """
  A simple verifier that can be used in conjunction with the retrying error_handler to stop halts on the first try
  """

  def init(opts) do
    Guardian.Plug.VerifySession.init(opts)
  end

  def call(conn, opts) do
    unhalting_opts = Keyword.merge(
      opts,
      [halt: false]
    )
    Guardian.Plug.VerifySession.call(conn, unhalting_opts)
  end
end
