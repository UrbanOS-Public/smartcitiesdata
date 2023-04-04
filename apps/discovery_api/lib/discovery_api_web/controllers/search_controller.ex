require Logger

defmodule DiscoveryApiWeb.SearchController do
  use Properties, otp_app: :discovery_api
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.SearchView
  alias DiscoveryApi.Search.Elasticsearch.Search

  plug(:accepts, SearchView.accepted_formats())

  getter(:raptor_url, generic: true)

  def advanced_search(conn, params) do
    sort = Map.get(params, "sort", "name_asc")
    current_user = conn.assigns.current_user
    api_key = Plug.Conn.get_req_header(conn, "api_key")
    IO.inspect(params, label: "TEST PARAMS")
    IO.inspect(sort, label: "TEST SORT")
    with {:ok, offset} <- extract_int_from_params(params, "offset", 0),
         {:ok, limit} <- extract_int_from_params(params, "limit", 10),
         {:ok, search_opts} <- build_search_opts(params, current_user, api_key, sort, offset, limit) |> IO.inspect(label: "TEST OPTS"),
         {:ok, models, facets, total} <- Search.search(search_opts) |> IO.inspect(label: "TEST RESPONSE") do
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

  defp get_groups(_current_user = nil, _api_key = nil), do: %{access_groups: [], organizations: []}

  defp get_groups(_current_user = nil, api_key) do
    RaptorService.list_groups_by_api_key(raptor_url(), api_key)
  end

  defp get_groups(current_user, _api_key) do
    RaptorService.list_groups_by_user(raptor_url(), current_user.subject_id)
  end

  defp build_search_opts(params, current_user, api_key, sort, offset, limit) do
    query = Map.get(params, "query", "")
    facets = Map.get(params, "facets", %{})
    api_accessible = parse_api_accessible(params)
    groups = get_groups(current_user, api_key)
    authorized_organization_ids = groups.organizations
    authorized_access_groups = groups.access_groups

    case validate_facets(facets) do
      {:ok, filter_facets} ->
        opts =
          [
            query: query,
            api_accessible: api_accessible,
            keywords: Map.get(filter_facets, :keywords),
            org_title: Map.get(filter_facets, :organization, []) |> List.first(),
            authorized_organization_ids: authorized_organization_ids,
            authorized_access_groups: authorized_access_groups,
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
