defmodule DiscoveryApiWeb.DatasetListController do
  use DiscoveryApiWeb, :controller

  def fetch_dataset_summaries(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    limit = Map.get(params, "limit", "10") |> String.to_integer
    offset = Map.get(params, "offset", "0") |> String.to_integer

    case DiscoveryApi.Data.Retriever.get_datasets() do
      {:ok, result} -> render(conn, :fetch_dataset_summaries, datasets: result, sort: sort_by, offset: offset, limit: limit)
      {:error, reason} ->  DiscoveryApiWeb.Renderer.render_500(conn, reason)
    end
  end

end
