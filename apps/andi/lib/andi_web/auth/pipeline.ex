defmodule AndiWeb.Auth.Pipeline do
  @moduledoc false

  use Guardian.Plug.Pipeline,
    otp_app: :andi,
    module: AndiWeb.Auth.TokenHandler,
    error_handler: AndiWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.VerifyHeader
  plug Guardian.Plug.LoadResource, allow_blank: false
end
