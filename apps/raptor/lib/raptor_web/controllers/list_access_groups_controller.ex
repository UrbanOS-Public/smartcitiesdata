defmodule RaptorWeb.ListAccessGroupsController do
  use RaptorWeb, :controller

  alias Raptor.Services.DatasetAccessGroupRelationStore
  require Logger

  plug(:accepts, ["json"])


  def list(conn, %{"dataset_id" => dataset_id}) do
    access_groups = DatasetAccessGroupRelationStore.get_all_by_dataset(dataset_id)
    render(conn, %{access_groups: access_groups})
  end

end
