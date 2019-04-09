defmodule DiscoveryApiWeb.DatasetPreviewController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Data.Dataset

  def fetch_preview(conn, _params) do
    conn.assigns.dataset
    |> run_query()
    |> return_preview(conn)
  end

  defp run_query(nil), do: []

  defp run_query(dataset) do
    dataset.systemName
    |> DiscoveryApiWeb.DatasetPrestoQueryService.preview()
  end

  defp return_preview(rows, conn), do: json(conn, %{data: rows})
end
