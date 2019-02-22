defmodule DiscoveryApiWeb.DatasetDetailController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_detail(conn, %{"dataset_id" => dataset_id}) do
    DiscoveryApi.Data.Retriever.get_dataset(dataset_id)
    |> (fn result -> render(conn, :fetch_dataset_detail, dataset: result) end).()
  end
end
