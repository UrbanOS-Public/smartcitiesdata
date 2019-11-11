defmodule DiscoveryApi.Auth.ErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, error, _opts) do
    Logger.error(inspect(error))
    DiscoveryApiWeb.RenderError.render_error(conn, 404, "Not Found")
  end
end
