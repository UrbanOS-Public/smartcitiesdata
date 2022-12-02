defmodule DiscoveryApiWeb.ApiKeyController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.ApiKeyView

  use Properties, otp_app: :discovery_api

  plug(:accepts, ["json"])
  getter(:raptor_url, generic: true)

  def regenerate_api_key(conn, _) do
    current_user = conn.assigns.current_user.subject_id

    case RaptorService.regenerate_api_key_for_user(raptor_url(), current_user) do
      {:error, error} ->
        Logger.error("DiscoveryApi failed to regenerate api key with error: #{inspect(error)}")
        render_error(conn, 500, "Internal Server Error")

      {:ok, result} ->
        render(conn, "regenerateApiKey.json", apiKey: result["apiKey"])
    end
  end
end
