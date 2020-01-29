defmodule DiscoveryApi.Repo do
  use Ecto.Repo,
    otp_app: :discovery_api,
    adapter: Ecto.Adapters.Postgres
end
