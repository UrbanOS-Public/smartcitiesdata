defmodule DiscoveryApiWeb.Plugs.NoStore do
  @moduledoc false
  require Logger
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    put_resp_header(conn, "cache-control", "no-store")
  end
end
