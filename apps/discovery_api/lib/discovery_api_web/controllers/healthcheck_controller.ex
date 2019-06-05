defmodule DiscoveryApiWeb.HealthCheckController do
  use DiscoveryApiWeb, :controller

  def index(conn, _params) do
    text(conn, "Hello, React!")
  end
end
