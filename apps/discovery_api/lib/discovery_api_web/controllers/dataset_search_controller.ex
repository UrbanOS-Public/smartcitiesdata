require Logger

defmodule DiscoveryApiWeb.DatasetSearchController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.Services.AuthService

  alias DiscoveryApi.Search.{DataModelFilterator, DataModelFacinator, DataModelSearchinator}

  @matched_params [
    %{"query" => "", "limit" => "10", "offset" => "0", "apiAccessible" => "false"},
    %{"limit" => "10", "offset" => "0", "apiAccessible" => "false"}
  ]

  plug DiscoveryApiWeb.Plugs.ResponseCache, %{for_params: @matched_params} when action in [:search]

  def search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")
    query = Map.get(params, "query", "")
    selected_facets = Map.get(params, "facets", %{})
    api_accessible = parse_api_accessible(params)

    with {:ok, offset} <- extract_int_from_params(params, "offset", 0),
         {:ok, limit} <- extract_int_from_params(params, "limit", 10),
         {:ok, filter_facets} <- validate_facets(selected_facets),
         search_result <- DataModelSearchinator.search(query),
         filtered_result <- DataModelFilterator.filter_by_facets(search_result, filter_facets),
         filtered_by_source_type_results <- filter_by_source_type(filtered_result, api_accessible),
         authorized_results <- remove_unauthorized_models(conn, filtered_by_source_type_results),
         facets <- DataModelFacinator.extract_facets(authorized_results, filter_facets) do
      render(
        conn,
        :search_dataset_summaries,
        models: authorized_results,
        facets: facets,
        sort: sort_by,
        offset: offset,
        limit: limit
      )
    else
      {:request_error, reason} -> render_error(conn, 400, reason)
      {:error, reason} -> render_error(conn, 500, reason)
    end
  end

  defp parse_api_accessible(params) do
    params
    |> Map.get("apiAccessible", "false")
    |> String.downcase()
    |> case do
      "true" -> true
      _ -> false
    end
  end

  defp filter_by_source_type(datasets, false), do: datasets

  defp filter_by_source_type(datasets, true) do
    Enum.reject(datasets, fn dataset -> dataset.sourceType == "remote" end)
  end

  defp remove_unauthorized_models(conn, filtered_models) do
    username = AuthService.get_user(conn)
    Enum.filter(filtered_models, &AuthService.has_access?(&1, username))
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
