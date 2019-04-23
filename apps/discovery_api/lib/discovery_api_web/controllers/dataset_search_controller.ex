require Logger

defmodule DiscoveryApiWeb.DatasetSearchController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.Services.AuthService

  alias DiscoveryApi.Search.{FacetFilterator, DatasetFacinator, DatasetSearchinator}

  def search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    query = Map.get(params, "query", "")
    facets = Map.get(params, "facets", %{})

    with {:ok, offset} <- extract_int_from_params(params, "offset", 0),
         {:ok, limit} <- extract_int_from_params(params, "limit", 10),
         {:ok, filter_facets} <- validate_facets(facets),
         {:ok, search_result} <- DatasetSearchinator.search(query: query),
         filtered_result <- FacetFilterator.filter_by_facets(search_result, filter_facets),
         authorized_results <- remove_unauthorized_datasets(conn, filtered_result),
         dataset_facets <- DatasetFacinator.get_facets(authorized_results) do
      render(
        conn,
        :search_dataset_summaries,
        datasets: authorized_results,
        facets: dataset_facets,
        sort: sort_by,
        offset: offset,
        limit: limit
      )
    else
      {:request_error, reason} -> render_error(conn, 400, reason)
      {:error, reason} -> render_error(conn, 500, reason)
    end
  end

  defp remove_unauthorized_datasets(conn, filtered_result) do
    username = AuthService.get_user(conn)
    Enum.filter(filtered_result, fn dataset -> AuthService.has_access?(dataset, username) end)
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
