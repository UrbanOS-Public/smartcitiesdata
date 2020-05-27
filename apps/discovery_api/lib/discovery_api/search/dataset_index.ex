defmodule DiscoveryApi.Search.DatasetIndex do
  @moduledoc """
  Manages an ElasticSearch index for datasets
  """
  alias DiscoveryApi.Data.Model

  def create_index() do
    %{name: name, options: options} = dataset_index()
    create_index(name, options)
  end

  def create_index(name, options \\ %{}) do
    elastic_create_index(name, options)
  end

  def delete_index() do
    delete_index(dataset_index_name())
  end

  def delete_index(name) do
    elastic_delete_index(name)
  end

  def get_index() do
    get_index(dataset_index_name())
  end

  def get_index(name) do
    elastic_get_index(name)
  end

  def reset_index() do
    reset_index(dataset_index())
  end

  def reset_index(name, options) do
    reset_index(%{name: name, options: options})
  end

  defp reset_index(%{name: name, options: options}) do
    case delete_index(name) do
      {:ok, _} -> create_index(name, options)
      error -> error
    end
  end

  def get(id) do
    case elastic_get(id) do
      {:ok, document} ->
        {:ok, struct(Model, document)}

      error ->
        error
    end
  end

  def get_all() do
    case elastic_search() do
      {:ok, documents, _facets} ->
        {:ok, Enum.map(documents, &struct(Model, &1))}

      error ->
        error
    end
  end

  def search(search_opts \\ []) do
    query = search_query(search_opts)

    case elastic_search(query) do
      {:ok, documents, facets} ->
        {:ok, Enum.map(documents, &struct(Model, &1)), facets}

      error ->
        error
    end
  end

  def update(%Model{} = dataset) do
    put(dataset, &elastic_update_document/1)
  end

  def replace(%Model{} = dataset) do
    put(dataset, &elastic_index_document/1)
  end

  def replace_all(datasets) do
    case reset_index(dataset_index()) do
      {:ok, _} -> elastic_bulk_document_load(datasets)
      error -> error
    end
  end

  defp put(%Model{id: _id} = dataset, operation_function) do
    dataset_as_map = dataset_to_map(dataset)

    case elastic_datasets_index_exists?() do
      true -> operation_function.(dataset_as_map)
      error -> error
    end
  end

  defp put(_dataset, _operation) do
    {:error, "Please provide a dataset with an id to update function."}
  end

  defp elastic_datasets_index_exists?() do
    Elastix.Index.exists?(url(), dataset_index_name())
    |> handle_index_exists_response()
  end

  defp elastic_index_document(dataset_as_map) do
    Elastix.Document.index(
      url(),
      dataset_index_name(),
      "_doc",
      dataset_as_map.id,
      dataset_as_map,
      refresh: true
    )
    |> handle_response()
  end

  defp elastic_update_document(dataset_as_map) do
    Elastix.Document.update(
      url(),
      dataset_index_name(),
      "_doc",
      dataset_as_map.id,
      %{doc: dataset_as_map, doc_as_upsert: true},
      refresh: true
    )
    |> handle_response()
  end

  defp elastic_create_index(name, options) do
    Elastix.Index.create(url(), name, options)
    |> handle_response_with_body()
  end

  defp elastic_delete_index(name) do
    Elastix.Index.delete(url(), name)
    |> handle_delete_index_response()
  end

  defp elastic_get_index(name) do
    Elastix.Index.get(url(), name)
    |> handle_response_with_body()
  end

  defp elastic_get(id) do
    case Elastix.Document.get(
           url(),
           dataset_index_name(),
           "_doc",
           id
         )
         |> handle_get_document_response() do
      {:ok, %{_source: document}} -> {:ok, document}
      error -> error
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
        documents = get_in(body, [:hits, :hits, Access.all(), :_source])
        facets = body |> Map.get(:aggregations, %{}) |> extract_facets()
        {:ok, documents, facets}

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

  defp elastic_bulk_document_load(datasets) do
    bulk_list = datasets_to_bulk_list(datasets)

    Elastix.Bulk.post(url(), bulk_list, [], refresh: true)
    |> handle_response()
  end

  defp datasets_to_bulk_list(datasets) do
    Enum.map(datasets, fn dataset ->
      [
        %{index: %{_id: dataset.id, _index: dataset_index_name()}},
        dataset_to_map(dataset)
      ]
    end)
    |> List.flatten()
  end

  defp handle_get_document_response({:ok, %{body: %{_id: id, found: false}}}), do: {:error, "Dataset with id #{id} not found!"}
  defp handle_get_document_response(response), do: handle_response_with_body(response)

  defp handle_index_exists_response({:ok, false}) do
    {:error, "Datasets index does not exist. Will not attempt to autocreate it."}
  end

  defp handle_index_exists_response({:ok, true}), do: true
  defp handle_index_exists_response(response), do: response

  defp handle_delete_index_response({:ok, %{body: %{error: %{type: "index_not_found_exception"}}}} = response), do: response
  defp handle_delete_index_response({:ok, %{body: %{error: error}}}), do: {:error, error}
  defp handle_delete_index_response(response), do: response

  defp handle_response({:ok, %{body: %{error: error}}}), do: {:error, error}
  defp handle_response(response), do: response

  defp handle_response_with_body({:ok, %{body: %{error: error}}}), do: {:error, error}
  defp handle_response_with_body({:ok, %{body: body}}), do: {:ok, body}
  defp handle_response_with_body(response), do: response

  defp dataset_to_map(dataset) do
    dataset
    |> Map.from_struct()
    |> Map.drop([:completeness])
    |> Map.put(:keywordFacets, Map.get(dataset, :keywords))
    |> Map.put(:orgTitleFacet, get_in(dataset, [:organizationDetails, :orgTitle]))
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp url() do
    Map.fetch!(configuration(), :url)
  end

  defp dataset_index_name() do
    dataset_index()
    |> Map.fetch!(:name)
  end

  defp dataset_index() do
    indices()
    |> Map.fetch!(:datasets)
  end

  defp indices() do
    Map.fetch!(configuration(), :indices)
  end

  defp configuration() do
    Application.get_env(:discovery_api, :elasticsearch)
    |> Map.new()
  end

  defp search_query(search_opts) do
    %{
      "aggs" => %{
        "keywords" => %{"terms" => %{"field" => "keywordFacets"}},
        "organization" => %{"terms" => %{"field" => "orgTitleFacet"}}
      },
      "from" => 0,
      "query" => %{
        "bool" => %{
          "must" => build_must(search_opts),
          "filter" => [
            %{"term" => %{"private" => false}}
          ]
        }
      },
      "size" => 10,
      "sort" => [%{"title" => %{"order" => "asc"}}]
    }
  end

  defp build_must(search_opts) do
    query = Keyword.get(search_opts, :query, "")
    keywords = Keyword.get(search_opts, :keywords, [])
    org_title = Keyword.get(search_opts, :org_title, nil)
    api_accessible = Keyword.get(search_opts, :api_accessible, false)

    [
      match_terms(query),
      match_keywords(keywords),
      match_organization(org_title),
      api_accessible(api_accessible)
    ] |> Enum.reject(&is_nil/1)
  end

  defp match_terms(term) when term in ["", nil] do
    %{
      "match_all" => %{}
    }
  end

  defp match_terms(term) do
    %{
      "multi_match" => %{
        "fields" => ["title", "description", "organizationDetails.orgTitle", "keywords"],
        "fuzziness" => "AUTO",
        "prefix_length" => 2,
        "query" => term,
        "type" => "most_fields"
      }
    }
  end

  defp match_keywords([]), do: nil

  defp match_keywords(keywords) do
    %{
      "terms_set" => %{
        "keywordFacets" => %{
            "terms" => keywords,
            "minimum_should_match_script" => %{
               "source" => "return #{length(keywords)}"
            }
        }
      }
    }
  end

  defp api_accessible(false), do: nil

  defp api_accessible(true) do
    %{
      "terms" => %{
        "sourceType" => ["ingest", "stream"]
      }
    }
  end

  defp match_organization(nil), do: nil

  defp match_organization(org_title) do
    %{
      "term" => %{
        "orgTitleFacet" => org_title
      }
    }
  end
end
