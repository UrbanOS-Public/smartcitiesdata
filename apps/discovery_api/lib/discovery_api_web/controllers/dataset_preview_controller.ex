defmodule DiscoveryApiWeb.DatasetPreviewController do
  @moduledoc false
  use DiscoveryApiWeb, :controller

  def fetch_preview(conn, %{"dataset_id" => dataset_id}) do
    case DiscoveryApiWeb.DatasetPrestoQueryService.preview(dataset_id) do
      rows -> json(conn, %{data: rows})
    end
  end
end
