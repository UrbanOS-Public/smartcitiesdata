require Logger

defmodule DiscoveryApiWeb.SearchController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.SearchView
  alias DiscoveryApi.Search.Elasticsearch.Search

  plug(:accepts, SearchView.accepted_formats())

  def advanced_search(conn, params) do
    sort = Map.get(params, "sort", "name_asc")
    current_user = conn.assigns.current_user

    with {:ok, offset} <- extract_int_from_params(params, "offset", 0),
         {:ok, limit} <- extract_int_from_params(params, "limit", 10),
         {:ok, search_opts} <- build_search_opts(params, current_user, sort, offset, limit),
         {:ok, models, facets, total} <- Search.search(search_opts) do
      render(
        conn,
        :search_view,
        models: models,
        facets: facets,
        offset: offset,
        limit: limit,
        total: total
      )
    else
      {:request_error, reason} ->
        render_error(conn, 400, reason)

      {:error, reason} ->
        Logger.error("Unhandled error in search #{inspect(reason)}")
        render_error(conn, 500, reason)
    end
  rescue
    e ->
      Logger.error("Unhandled error in search #{inspect(e)}")
      reraise e, __STACKTRACE__
  end

  defp build_search_opts(params, current_user, sort, offset, limit) do
    query = Map.get(params, "query", "")
    facets = Map.get(params, "facets", %{})
    api_accessible = parse_api_accessible(params)

    authorized_organization_ids =
      case current_user do
        nil -> nil
        _ -> Enum.map(current_user.organizations, fn organization -> organization.id end)
      end

    case validate_facets(facets) do
      {:ok, filter_facets} ->
        opts =
          [
            query: query,
            api_accessible: api_accessible,
            keywords: Map.get(filter_facets, :keywords),
            org_title: Map.get(filter_facets, :organization, []) |> List.first(),
            authorized_organization_ids: authorized_organization_ids,
            sort: sort,
            offset: offset,
            limit: limit
          ]
          |> Enum.reject(fn {_opt, value} -> is_nil(value) end)

        {:ok, opts}

      error ->
        error
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
