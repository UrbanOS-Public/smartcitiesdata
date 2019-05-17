defmodule DiscoveryApi.Auth.Pipeline do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :discovery_api,
    module: DiscoveryApi.Auth.Guardian,
    error_handler: DiscoveryApi.Auth.ErrorHandler

  plug(DiscoveryApiWeb.Plugs.CookieMonster)
  plug(Guardian.Plug.VerifyHeader, claims: %{iss: "discovery_api"}, realm: "Bearer")
  plug(Guardian.Plug.VerifyCookie)
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end
