defmodule RaptorWeb.ApiKeyController do
  use RaptorWeb, :controller

  alias Raptor.Services.Auth0Management
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  require Logger

  plug(:accepts, ["json"])

  def regenerateApiKey(conn, %{"user_id" => user_id}) do
    new_api_key = randomApiKey(24)

    case Auth0Management.patch_api_key(user_id, new_api_key) do
      {:ok, response} ->
        {:ok, body} = Jason.decode(response.body)
        render(conn, %{apiKey: body["app_metadata"]["apiKey"]})

      {:error, response} ->
        Logger.error("Auth0 returned error patching API key #{inspect(response)}")
        render_error(conn, 500, "Internal Server Error")
    end
  end

  def regenerateApiKey(conn, _) do
    Logger.error("Someone attempted to generate an api key with no user_id")
    render_error(conn, 400, "user_id is a required parameter")
  end

  defp randomApiKey(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
