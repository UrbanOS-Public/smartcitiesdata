defmodule DiscoveryApiWeb.HealthCheckController do
  @moduledoc """
  Simple healthcheck controller
  """
  use DiscoveryApiWeb, :controller

  def index(conn, _params) do
    text(conn, "Hello, React!")
  end
end
