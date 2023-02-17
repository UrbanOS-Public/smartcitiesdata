defmodule RaptorWeb.ListAccessGroupsController do
  use RaptorWeb, :controller

  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Services.UserAccessGroupRelationStore
  alias Raptor.Services.Auth0Management
  alias Raptor.Services.UserOrgAssocStore
  require Logger

  plug(:accepts, ["json"])

  def list(conn, %{"dataset_id" => dataset_id}) do
    access_groups = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)
    render(conn, %{access_groups: access_groups})
  end

  def list(conn, %{"user_id" => user_id}) do
    access_groups = UserAccessGroupRelationStore.get_all_by_user(user_id)
    organizations = UserOrgAssocStore.get_all_by_user(user_id)
    render(conn, %{access_groups: access_groups, organizations: organizations})
  end

  def list(conn, %{"api_key" => api_key}) do
    {:ok, users} = Auth0Management.get_users_by_api_key(api_key)

    case length(users) do
      0 ->
        Logger.warn("No users exist in Auth0 with the provided API Key.")
        render(conn, %{access_groups: [], organizations: []})

      1 ->
        access_groups =
          List.first(users)
          |> Map.get(:user_id)
          |> UserAccessGroupRelationStore.get_all_by_user()

        organizations =
          List.first(users) |> Map.get(:user_id) |> UserOrgAssocStore.get_all_by_user()

        render(conn, %{access_groups: access_groups, organizations: organizations})

      _ ->
        Logger.warn(
          "Multiple users exist in Auth0 with the provided API Key. This is not permissible."
        )

        render(conn, %{access_groups: [], organizations: []})
    end
  end

  def list(conn, _) do
    render_error(conn, 400, "dataset_id, api_key, or user_id must be passed.")
  end
end
