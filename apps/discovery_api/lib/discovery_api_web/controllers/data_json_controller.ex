defmodule DiscoveryApiWeb.DataJsonController do
  use DiscoveryApiWeb, :controller

  plug DiscoveryApiWeb.Plugs.DataJson

  def show(conn, _params) do
    conn
  end
end
