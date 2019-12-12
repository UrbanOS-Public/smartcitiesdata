defmodule DiscoveryStreamsWeb.HealthCheckController do
  use DiscoveryStreamsWeb, :controller

  def index(conn, _params) do
    text(conn, "Up")
  end
end
