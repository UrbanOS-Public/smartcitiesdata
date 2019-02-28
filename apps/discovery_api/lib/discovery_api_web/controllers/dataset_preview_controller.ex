defmodule DiscoveryApiWeb.DatasetPreviewController do
  use DiscoveryApiWeb, :controller

  def fetch_preview(conn, %{"dataset_id" => dataset_id}) do
    case DiscoveryApiWeb.DatasetPrestoQueryService.preview(dataset_id) do
      rows -> json(conn, %{data: rows})
    end
  end
end
