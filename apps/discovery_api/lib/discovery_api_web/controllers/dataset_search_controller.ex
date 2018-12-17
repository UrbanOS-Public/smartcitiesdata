require Logger

defmodule DiscoveryApiWeb.DatasetSearchController do
  use DiscoveryApiWeb, :controller

  def search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    limit = Map.get(params, "limit", "10") |> String.to_integer()
    offset = Map.get(params, "offset", "0") |> String.to_integer()
    query = Map.get(params, "query", "")

    case Data.DatasetSearchinator.search(query: query) do
      {:error, reason} -> DiscoveryApiWeb.Renderer.render_500(conn, reason)
      {:ok, result} ->
        render(conn, :search_dataset_summaries,
          datasets: result,
          sort: sort_by,
          offset: offset,
          limit: limit
        )
    end
  end
end
