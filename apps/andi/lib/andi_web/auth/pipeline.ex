defmodule Andi.Auth.Pipeline do
  use Guardian.Plug.Pipeline, otp_app: :andi,
    module: AndiWeb.Auth.TokenHandler,
    error_handler: AndiWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.VerifyHeader
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, allow_blank: false
end
