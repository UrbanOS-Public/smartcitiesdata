defmodule RaptorWeb.AuthorizeController do
  use RaptorWeb, :controller

  alias Raptor.Services.Auth0Management
  alias Raptor.Services.DatasetStore
  alias Raptor.Schemas.Auth0UserData
  alias Raptor.Services.UserOrgAssocStore
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Services.DatasetAccessGroupRelationStore
  require Logger

  plug(:accepts, ["json"])

  def is_user_in_org?(user_id, org_id) do
    UserOrgAssocStore.get(user_id, org_id) != %{}
  end

  @spec is_user_in_access_group?(binary, any) :: any
  def is_user_in_access_group?(user_id, dataset_id) do
    user_access_groups = UserAccessGroupRelationStore.get_all_by_user(user_id)
    dataset_access_groups = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)

    Enum.any?(user_access_groups, fn user_access_group ->
      Enum.member?(dataset_access_groups, user_access_group)
    end)
  end

  def is_valid_dataset?(dataset) do
    dataset != %{}
  end

  def check_user_association(%Auth0UserData{} = user, dataset) do
    org_id_of_dataset = dataset.org_id

    is_user_in_org?(user.user_id, org_id_of_dataset) or
      is_user_in_access_group?(user.user_id, dataset.dataset_id)
  end

  def validate_user_list(user_list, dataset) do
    case length(user_list) do
      0 ->
        Logger.warn("No user found with given API Key.")
        false

      1 ->
        user = user_list |> Enum.at(0)

        if(Auth0Management.is_valid_user(user)) do
          check_user_association(user, dataset)
        else
          # Only users who have validated their email address and aren't blocked may make API calls
          false
        end

      _ ->
        Logger.warn("Multiple users cannot have the same API Key.")
        false
    end
  end

  def authorize(conn, %{"auth0_user" => auth0_user, "systemName" => systemName}) do
    dataset_associated_with_system_name = DatasetStore.get(systemName)

    if(is_valid_dataset?(dataset_associated_with_system_name)) do
      if dataset_associated_with_system_name.is_private do
        render(conn, %{
          is_authorized:
            is_user_in_org?(auth0_user, dataset_associated_with_system_name.org_id) or
              is_user_in_access_group?(auth0_user, dataset_associated_with_system_name.dataset_id)
        })
      else
        render(conn, %{is_authorized: true})
      end
    else
      render(conn, %{is_authorized: false})
    end
  end

  def authorize(conn, %{"apiKey" => apiKey, "systemName" => systemName}) do
    dataset_associated_with_system_name = DatasetStore.get(systemName)

    if(is_valid_dataset?(dataset_associated_with_system_name)) do
      if dataset_associated_with_system_name.is_private do
        case Auth0Management.get_users_by_api_key(apiKey) do
          {:ok, user_list} ->
            render(conn, %{
              is_authorized: validate_user_list(user_list, dataset_associated_with_system_name)
            })

          {:error, _} ->
            render(conn, %{is_authorized: false})
        end
      else
        render(conn, %{is_authorized: true})
      end
    else
      render(conn, %{is_authorized: false})
    end
  end

  def authorize(conn, %{"apiKey" => _}) do
    render_error(conn, 400, "systemName is a required parameter.")
  end

  def authorize(conn, %{"auth0_user" => _}) do
    render_error(conn, 400, "systemName is a required parameter.")
  end

  def authorize(conn, %{"systemName" => systemName}) do
    dataset_associated_with_system_name = DatasetStore.get(systemName)

    if(is_valid_dataset?(dataset_associated_with_system_name)) do
      if DatasetStore.get(systemName).is_private do
        render_error(conn, 400, "apiKey is a required parameter to access private datasets.")
      else
        render(conn, %{is_authorized: true})
      end
    else
      render(conn, %{is_authorized: false})
    end
  end

  def authorize(conn, _) do
    render_error(conn, 400, "systemName is a required parameter.")
  end
end
