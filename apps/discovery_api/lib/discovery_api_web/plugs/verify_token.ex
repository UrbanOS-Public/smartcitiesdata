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
    case Application.get_env(:discovery_api, :auth_provider) do
      "auth0" ->
        DiscoveryApiWeb.Plugs.VerifyHeaderAuth0.call(conn, opts)

      _ ->
        conn
        |> Guardian.Plug.VerifyHeader.call(opts)
        |> Guardian.Plug.VerifyCookie.call(opts)
    end
  end
end
