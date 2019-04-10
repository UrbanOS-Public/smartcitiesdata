defmodule DiscoveryApiWeb.DatasetPreviewController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.DatasetPrestoQueryService

  def fetch_preview(conn, _params) do
    conn.assigns.dataset.systemName
    |> DatasetPrestoQueryService.preview()
    |> return_preview(conn)
  end

  defp return_preview(rows, conn), do: json(conn, %{data: rows})
end
