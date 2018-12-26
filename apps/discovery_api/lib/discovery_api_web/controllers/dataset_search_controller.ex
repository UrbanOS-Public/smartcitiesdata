require Logger

defmodule DiscoveryApiWeb.DatasetSearchController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Search.{FacetFilterator, DatasetFacinator, DatasetSearchinator}
  alias DiscoveryApiWeb.Renderer

  def search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    limit = Map.get(params, "limit", "10") |> String.to_integer()
    offset = Map.get(params, "offset", "0") |> String.to_integer()
    query = Map.get(params, "query", "")
    filter_facets = Map.get(params, "facets", %{})

    case DatasetSearchinator.search(query: query) do
      {:error, reason} ->
        Renderer.render_500(conn, reason)

      {:ok, search_result} ->
        filtered_result = FacetFilterator.filter_by_facets(search_result, filter_facets)
        dataset_facets = DatasetFacinator.get_facets(filtered_result)

        render(conn, :search_dataset_summaries,
          datasets: filtered_result,
          facets: dataset_facets,
          sort: sort_by,
          offset: offset,
          limit: limit
        )
    end
  end
end
