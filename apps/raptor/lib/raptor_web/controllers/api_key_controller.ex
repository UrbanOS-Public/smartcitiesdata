defmodule RaptorWeb.ApiKeyController do
  use RaptorWeb, :controller

  alias Raptor.Services.Auth0Management
  require Logger

  plug(:accepts, ["json"])

  def regenerateApiKey(conn, %{"auth0_user" => user}) do
    IO.inspect(user, label: "Auth0 User")

    newApiKey = randomApiKey()
    response = Auth0Management.patch_api_key(newApiKey)

  end

  def regenerateApiKey(conn, _) do
      render_error(conn, 400, "user_id is a required parameter")
    end

  defp randomApiKey() do
    "iliketuttles"
  end
end
