defmodule DiscoveryApi.Auth.Pipeline do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :discovery_api,
    module: DiscoveryApi.Auth.Guardian,
    error_handler: DiscoveryApi.Auth.ErrorHandler

  @claims %{iss: "discovery_api"}

  plug(Guardian.Plug.VerifyHeader, claims: @claims, realm: "Bearer")
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end
