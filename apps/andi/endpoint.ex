defmodule Andi.Endpoint do
  use Phoenix.Endpoint, otp_app: :andi

  plug Plug.Static,
    at: "/",
    from: :andi,
    gzip: false,
    only: ~w(css fonts images js favicon.ico)
end
