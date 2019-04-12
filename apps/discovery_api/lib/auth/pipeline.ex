defmodule DiscoveryApi.Auth.Pipeline do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :discovery_api,
    module: DiscoveryApi.Auth.Guardian,
    error_handler: DiscoveryApi.Auth.ErrorHandler

  plug(Guardian.Plug.VerifyCookie)
  plug(Guardian.Plug.LoadResource, allow_blank: true)
end
