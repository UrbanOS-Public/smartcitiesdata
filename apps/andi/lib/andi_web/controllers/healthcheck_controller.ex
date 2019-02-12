defmodule AndiWeb.HealthCheckController do
  use AndiWeb, :controller

  def index(conn, _params) do
    text(conn, "Up")
  end
end
