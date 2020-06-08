defmodule DiscoveryApiWeb.Auth.ErrorHandler do
  @moduledoc false
  @behaviour Guardian.Plug.ErrorHandler

  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, error, _opts) do
    Logger.error("Auth failed: #{inspect(error)}")

    error_message =
      "Unauthorized"
      |> DiscoveryApiWeb.ErrorView.fill_json_template()
      |> Jason.encode!()

    Plug.Conn.resp(conn, 401, error_message)
  end
end
