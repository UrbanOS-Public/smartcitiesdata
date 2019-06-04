defmodule DiscoveryApi.Auth.ErrorHandler do
  @moduledoc """
  Module for handling authentication errors.
  """
  @behaviour Guardian.Plug.ErrorHandler

  require Logger
  import Plug.Conn

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, error, _opts) do
    Logger.error(inspect(error))

    conn
    |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
    |> halt()
  end
end
