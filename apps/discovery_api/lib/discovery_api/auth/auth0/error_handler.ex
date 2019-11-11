defmodule DiscoveryApi.Auth.Auth0.ErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, error, _opts) do
    Logger.error("Auth failed: #{inspect(error)}")
    DiscoveryApiWeb.RenderError.render_error(conn, 400, "Bad Request")
  end
end
