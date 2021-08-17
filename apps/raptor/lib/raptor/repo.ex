defmodule Raptor.Repo do
  use Ecto.Repo,
    otp_app: :raptor,
    adapter: Ecto.Adapters.Postgres
end
