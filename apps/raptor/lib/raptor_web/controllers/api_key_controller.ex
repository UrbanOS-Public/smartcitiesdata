defmodule RaptorWeb.ApiKeyController do
  use RaptorWeb, :controller

  alias Raptor.Services.Auth0Management
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  require Logger

  plug(:accepts, ["json"])

  def regenerateApiKey(conn, %{"auth0_user" => user}) do
    #TODO: Test
    IO.inspect(user, label: "Auth0 User")

    new_api_key = randomApiKey(24)
    response = Auth0Management.patch_api_key(new_api_key)
    render(conn, %{apiKey: new_api_key})
  end

  def regenerateApiKey(conn, _) do
    #TODO: Test
      render_error(conn, 400, "user_id is a required parameter")
    end

  defp randomApiKey(length) do
    #TODO: Test
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
