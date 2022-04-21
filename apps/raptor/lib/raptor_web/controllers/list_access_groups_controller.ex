defmodule RaptorWeb.ListAccessGroupsController do
  use RaptorWeb, :controller

  alias Raptor.Services.DatasetAccessGroupRelationStore
  alias Raptor.Services.UserAccessGroupRelationStore
  require Logger

  plug(:accepts, ["json"])


  def list(conn, %{"dataset_id" => dataset_id}) do
    access_groups = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)
    render(conn, %{access_groups: access_groups})
  end

  def list(conn, %{"user_id" => user_id}) do
    access_groups = UserAccessGroupRelationStore.get_all_by_user(user_id)
    render(conn, %{access_groups: access_groups})
  end

  def list(conn, _) do
    render_error(conn, 400, "dataset_id or user_id must be passed.")
  end

end
