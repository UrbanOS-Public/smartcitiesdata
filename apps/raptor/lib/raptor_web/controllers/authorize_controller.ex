defmodule RaptorWeb.AuthorizeController do
  use RaptorWeb, :controller

  alias Raptor.Services.Auth0Management
  require Logger

  plug(:accepts, ["json"])

  def check_user_association(user, datasetName) do
      # check what organization the dataset belongs to

      # User-Org Table
      # user | {orgs: [{orgId, orgName}]}

      # Dataset-Org Table
      # datasetId | datasetName | orgId | orgName

      # check what organizations the user belongs to

      # check if there is a match

      # return true if there is a match or false if there is not
      true

  end

  def validate_user_list(user_list, datasetName) do
    case length(user_list) do
      0 ->
        Logger.warn("No user found with given API Key.")
        false

      1 ->
        user = user_list |> Enum.at(0)
        if(user["email_verified"]) do
          check_user_association(user, datasetName)
        else
          # Only users who have validated their email address may make API calls
          false
        end


      _ ->
        Logger.warn("Multiple users cannot have the same API Key.")
        false
    end
  end

  def authorize(conn, %{"apiKey" => apiKey, "datasetName" => datasetName}) do
    case Auth0Management.get_users_by_api_key(apiKey) do
      {:ok, user_list} -> render(conn, %{is_authorized: validate_user_list(user_list, datasetName)})
      {:error, _} -> render(conn, %{is_authorized: false})
    end
  end
end
