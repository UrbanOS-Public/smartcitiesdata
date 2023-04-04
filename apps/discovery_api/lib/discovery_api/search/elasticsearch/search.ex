defmodule DiscoveryApi.Search.Elasticsearch.Search do
  @moduledoc """
  Manages invoking an Elasticsearch query and formatting it's response
  """
  require Logger
  alias DiscoveryApi.Data.Model
  import DiscoveryApi.Search.Elasticsearch.Shared
  alias DiscoveryApi.Search.Elasticsearch.QueryBuilder

  def get_all() do
    case elastic_search() do
      {:ok, documents, _facets, _total} ->
        {:ok, Enum.map(documents, &struct(Model, &1))}

      error ->
        error
    end
  end

  def search(search_opts \\ []) do
    query = QueryBuilder.build(search_opts)

    case elastic_search(query) do
      {:ok, documents, facets, total} ->
        {:ok, Enum.map(documents, &struct(Model, &1)), facets, total}

      error ->
        error
    end
  end

  defp elastic_search(options \\ %{}) do
    case Elastix.Search.search(
           url(),
           dataset_index_name(),
           ["_doc"],
           options
         )
         |> handle_response_with_body() do
      {:ok, body} ->
        IO.inspect(label: "SEARCH BODY")
        Logger.debug("#{__MODULE__}: ElasticSearch Response: #{inspect(body)}")
        total = get_in(body, [:hits, :total, :value])
        documents = get_in(body, [:hits, :hits, Access.all(), :_source])
        facets = body |> Map.get(:aggregations, %{}) |> extract_facets()
        {:ok, documents, facets, total}

      error ->
        error
    end
  end

  defp extract_facets(aggregations) do
    aggregations
    |> Enum.map(fn {facet, %{buckets: buckets}} -> {facet, buckets_to_facet_values(buckets)} end)
    |> Enum.reduce(%{}, fn {facet, values}, facets -> Map.put(facets, facet, values) end)
  end

  defp buckets_to_facet_values(buckets) do
    Enum.map(buckets, fn %{doc_count: count, key: name} -> %{name: name, count: count} end)
  end
end
