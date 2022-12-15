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

  def getUserIdFromApiKey(conn, %{"api_key" => api_key}) do
    case Auth0Management.get_users_by_api_key(api_key) do
      {:ok, user_list} ->
        case get_valid_user_id(user_list) do
          {:ok, user_id} ->
            render(conn, %{
              user_id: user_id
            })
          {:error, reason} -> render_error(conn, 401, reason)
        end

      {:error, _} ->
        render_error(conn, 500, "Internal Server Error")
    end
  end

  defp randomApiKey(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  defp get_valid_user_id(user_list) do
    case length(user_list) do
      0 ->
        Logger.warn("No user found with given API Key.")
        {:error, "No user found with given API Key."}

      1 ->
        user = user_list |> Enum.at(0)

        if(user["email_verified"] and !user["blocked"]) do
          {:ok, user["user_id"]}
        else
          {:error, "Only users who have validated their email address and aren't blocked may make API calls"}
        end

      _ ->
        Logger.warn("Multiple users cannot have the same API Key.")
        {:error, "Multiple users cannot have the same API Key."}
    end
  end
end
