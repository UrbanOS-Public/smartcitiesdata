defmodule DiscoveryApiWeb.HealthCheckController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def index(conn, _params) do
    text(conn, "Hello, React!")
  end
end
