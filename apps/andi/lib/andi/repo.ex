defmodule Andi.Repo do
  use Ecto.Repo,
    otp_app: :andi,
    adapter: Ecto.Adapters.Postgres
end
