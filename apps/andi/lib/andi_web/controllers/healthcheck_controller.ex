defmodule AndiWeb.HealthCheckController do
  @moduledoc """
  Module handles requests to validate the system is up.
  """
  use AndiWeb, :controller

  access_levels [
    index: [:private, :public]
  ]

  @spec index(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def index(conn, _params) do
    text(conn, "Up")
  end
end
