defmodule DiscoveryApiWeb.DatasetPreviewController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.DatasetPrestoQueryService

  def fetch_preview(conn, _params) do
    columns =
      conn.assigns.model.systemName
      |> DatasetPrestoQueryService.preview_columns()

    conn.assigns.model.systemName
    |> DatasetPrestoQueryService.preview()
    |> return_preview(columns, conn)
  end

  defp return_preview(rows, columns, conn), do: json(conn, %{data: rows, meta: %{columns: columns}})
end
