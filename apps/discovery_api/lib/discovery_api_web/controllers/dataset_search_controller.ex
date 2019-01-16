require Logger

defmodule DiscoveryApiWeb.DatasetSearchController do
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Search.{FacetFilterator, DatasetFacinator, DatasetSearchinator}

  def search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    query = Map.get(params, "query", "")
    facets = Map.get(params, "facets", %{})

    with {:ok, offset} <- extract_int_from_params(params, "offset", 0),
         {:ok, limit} <- extract_int_from_params(params, "limit", 10),
         {:ok, filter_facets} <- validate_facets(facets),
         {:ok, search_result} <- DatasetSearchinator.search(query: query) do
      filter_and_render(
        conn,
        search_result,
        filter_facets,
        sort_by,
        offset,
        limit
      )
    else
      {:request_error, reason} -> render_error(conn, 400, reason)
      {:error, reason} -> render_error(conn, 500, reason)
    end
  end

  defp filter_and_render(conn, search_result, filter_facets, sort_by, offset, limit) do
    filtered_result = FacetFilterator.filter_by_facets(search_result, filter_facets)
    dataset_facets = DatasetFacinator.get_facets(filtered_result)

    render(
      conn,
      :search_dataset_summaries,
      datasets: filtered_result,
      facets: dataset_facets,
      sort: sort_by,
      offset: offset,
      limit: limit
    )
  end

  defp validate_facets(map) do
    try do
      {:ok, Enum.reduce(map, %{}, &atomize_map/2)}
    rescue
      ArgumentError ->
        {:request_error, "Error: Invalid Facets (#{inspect(map)})"}
    end
  end

  defp atomize_map({facet_name, facet_values} = _facet, atom_map) do
    Map.put(atom_map, String.to_existing_atom(facet_name), facet_values)
  end
end
