defmodule DiscoveryApiWeb.DatasetDetailController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def fetch_dataset_detail(conn, %{"dataset_id" => dataset_id}) do
    case DiscoveryApi.Data.Retriever.get_dataset(dataset_id) do
      nil -> render_error(conn, 404, "Not Found")
      result -> render(conn, :fetch_dataset_detail, dataset: result)
    end
  end
end
