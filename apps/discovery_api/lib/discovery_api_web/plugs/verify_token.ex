defmodule DiscoveryApiWeb.Plugs.VerifyToken do
  @moduledoc """
  This plug is used to verify authentication tokens.
  * When configured to use Auth0, we delegate to the plug that loads that necessary JWK.S
  * Otherwise we delegate to the default Guardian VerifyHeader and VerifyCookie plugs.
  """

  def init(opts) do
    opts
    |> Guardian.Plug.VerifyHeader.init()
    |> Guardian.Plug.VerifyCookie.init()
  end

  def call(conn, opts) do
    DiscoveryApiWeb.Plugs.VerifyHeaderAuth0.call(conn, opts)
  end
end
