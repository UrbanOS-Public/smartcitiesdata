defmodule DiscoveryApiWeb.Plugs.NoStore do
  @moduledoc false
  require Logger
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    conn
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("pragma", "no-cache")
  end
end
