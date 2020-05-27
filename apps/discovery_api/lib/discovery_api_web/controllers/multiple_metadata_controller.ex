require Logger

defmodule DiscoveryApiWeb.MultipleMetadataController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApiWeb.MultipleMetadataView
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Data.TableInfoCache
  alias DiscoveryApi.Search.{DataModelFilterator, DataModelFacinator, DataModelSearchinator}
  alias DiscoveryApi.Search.DatasetIndex, as: DatasetSearchIndex

  @matched_params [
    %{"query" => "", "limit" => "10", "offset" => "0", "apiAccessible" => "false"},
    %{"limit" => "10", "offset" => "0", "apiAccessible" => "false"}
  ]

  plug(:accepts, MultipleMetadataView.accepted_formats())
  plug(DiscoveryApiWeb.Plugs.ResponseCache, %{for_params: @matched_params} when action in [:search])

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

  def advanced_search(conn, params) do
    sort_by = Map.get(params, "sort", "name_asc")

    with {:ok, search_opts} <- build_search_opts(params),
         {:ok, models, facets} <- DatasetSearchIndex.search(search_opts) do
      render(
        conn,
        :search_dataset_summaries,
        models: models,
        facets: facets,
        sort: sort_by,
        offset: 0,
        limit: 10
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

  def fetch_table_info(conn, _params) do
    user_id = get_user_id(conn)

    filtered_models =
      case TableInfoCache.get(user_id) do
        nil ->
          remove_unauthorized_models(conn, Model.get_all())
          |> get_filtered_table_info()
          |> TableInfoCache.put(user_id)

        filtered_models ->
          filtered_models
      end

    render(
      conn,
      :fetch_table_info,
      models: filtered_models
    )
  end

  defp build_search_opts(params) do
    query = Map.get(params, "query", "")
    facets = Map.get(params, "facets", %{})
    api_accessible = parse_api_accessible(params)

    case validate_facets(facets) do
      {:ok, filter_facets} ->
        opts =
          [
            query: query,
            api_accessible: api_accessible,
            keywords: Map.get(filter_facets, :keywords),
            org_title: Map.get(filter_facets, :organization, []) |> List.first()
          ]
          |> Enum.reject(fn {_opt, value} -> is_nil(value) end)

        {:ok, opts}

      error ->
        error
    end
  end

  defp get_user_id(conn) do
    case conn.assigns.current_user do
      nil -> nil
      user -> Map.get(user, :subject_id)
    end
  end

  defp get_filtered_table_info(models) do
    models
    |> filter_by_file_types(["CSV", "GEOJSON"])
    |> filter_by_source_type(true)
    |> Enum.map(&Model.to_table_info/1)
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

  defp filter_by_file_types(datasets, accepted_file_types) do
    Enum.filter(datasets, fn dataset ->
      matching_file_types =
        dataset.fileTypes
        |> Enum.filter(&Enum.member?(accepted_file_types, &1))

      Enum.count(matching_file_types) > 0
    end)
  end

  defp filter_by_source_type(datasets, false), do: datasets

  defp filter_by_source_type(datasets, true) do
    Enum.filter(datasets, fn dataset -> dataset.sourceType in ["ingest", "stream"] end)
  end

  defp remove_unauthorized_models(conn, filtered_models) do
    current_user = conn.assigns.current_user
    Enum.filter(filtered_models, &ModelAccessUtils.has_access?(&1, current_user))
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
