defmodule RaptorWeb.AuthorizeController do
  use RaptorWeb, :controller

  alias Raptor.Services.Auth0Management
  alias Raptor.Services.DatasetStore
  alias Raptor.Services.UserOrgAssocStore
  require Logger

  plug(:accepts, ["json"])

  def is_user_in_org?(user_id, org_id) do
    UserOrgAssocStore.get(user_id, org_id) != %{}
  end

  def is_valid_dataset?(dataset) do
    dataset != %{}
  end

  def check_user_association(user, systemName) do
    dataset_associated_with_system_name = DatasetStore.get(systemName)

    if(is_valid_dataset?(dataset_associated_with_system_name)) do
      org_id_of_dataset = dataset_associated_with_system_name.org_id
      is_user_in_org?(user["user_id"], org_id_of_dataset)
    else
      false
    end
  end

  def validate_user_list(user_list, systemName) do
    case length(user_list) do
      0 ->
        Logger.warn("No user found with given API Key.")
        false

      1 ->
        user = user_list |> Enum.at(0)

        if(user["email_verified"]) do
          check_user_association(user, systemName)
        else
          # Only users who have validated their email address may make API calls
          false
        end

      _ ->
        Logger.warn("Multiple users cannot have the same API Key.")
        false
    end
  end

  def authorize(conn, %{"apiKey" => apiKey, "systemName" => systemName}) do
    case DatasetStore.get(systemName).is_private do
      true ->
        case Auth0Management.get_users_by_api_key(apiKey) do
          {:ok, user_list} ->
            render(conn, %{is_authorized: validate_user_list(user_list, systemName)})

          {:error, _} ->
            render(conn, %{is_authorized: false})
        end

      false ->
        render(conn, %{is_authorized: true})
    end
  end

  def authorize(conn, %{"apiKey" => _}) do
    render_error(conn, 400, "systemName is a required parameter.")
  end

  def authorize(conn, %{"systemName" => systemName}) do
    case DatasetStore.get(systemName).is_private do
      true ->
        render_error(conn, 400, "apiKey is a required parameter to access private datasets.")

      false ->
        render(conn, %{is_authorized: true})
    end
  end

  def authorize(conn, _) do
    render_error(conn, 400, "systemName is a required parameter.")
  end
end
