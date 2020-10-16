defmodule Auth.Repo do
  @moduledoc """
  Ecto demands a real database for testing, so here it is
  """

  use Ecto.Repo,
    otp_app: :auth,
    adapter: Ecto.Adapters.Postgres
end
