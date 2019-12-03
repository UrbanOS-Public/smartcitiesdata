defmodule DiscoveryApi.Auth.ErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, error, _opts) do
    Logger.error("Auth failed: #{inspect(error)}")
    DiscoveryApiWeb.RenderError.render_error(conn, 401, "Unauthorized")
  end
end
