defmodule DiscoveryApi.Search.Elasticsearch.Document do
  @moduledoc """
  Manages basic CRUD operations for a Dataset Document
  """
  alias DiscoveryApi.Data.Model
  import DiscoveryApi.Search.Elasticsearch.Shared

  def get(id) do
    case elastic_get(id) do
      {:ok, document} ->
        {:ok, struct(Model, document)}

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

  def delete(dataset_id) do
    elastic_delete_document(dataset_id)
  end

  def replace_all(datasets) do
    case DiscoveryApi.Search.Elasticsearch.DatasetIndex.reset(dataset_index()) do
      {:ok, _} -> elastic_bulk_document_load(datasets)
      error -> error
    end
  end

  defp put(%Model{id: _id} = dataset, operation_function) do
    dataset_as_map = dataset_to_map(dataset)

    case DiscoveryApi.Search.Elasticsearch.DatasetIndex.elastic_datasets_index_exists?() do
      true -> operation_function.(dataset_as_map)
      error -> error
    end
  end

  defp put(_dataset, _operation) do
    {:error, "Please provide a dataset with an id to update function."}
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

  defp elastic_delete_document(dataset_id) do
    Elastix.Document.delete(
      url(),
      dataset_index_name(),
      "_doc",
      dataset_id
    )
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

  defp dataset_to_map(dataset) do
    dataset
    |> Map.from_struct()
    |> Map.drop([:completeness])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> populate_org_facets()
    |> populate_keyword_facets()
    |> populate_optimized_fields()
    |> populate_sort_date()
  end

  defp populate_sort_date(%{sourceType: "ingest", modifiedDate: sortDate} = model), do: Map.put(model, :sortDate, sortDate)
  defp populate_sort_date(%{sourceType: "stream", lastUpdatedDate: sortDate} = model), do: Map.put(model, :sortDate, sortDate)
  defp populate_sort_date(%{issuedDate: sortDate} = model), do: Map.put(model, :sortDate, sortDate)
  defp populate_sort_date(model), do: model

  defp populate_org_facets(%{organizationDetails: %{orgTitle: org_title}} = dataset) do
    Map.put_new(dataset, :facets, %{})
    |> put_in([:facets, :orgTitle], org_title)
  end

  defp populate_org_facets(dataset), do: dataset

  defp populate_keyword_facets(%{keywords: keywords} = dataset) do
    Map.put_new(dataset, :facets, %{})
    |> put_in([:facets, :keywords], keywords)
  end

  defp populate_keyword_facets(dataset), do: dataset

  defp populate_optimized_fields(dataset) do
    put_in(dataset, [:titleKeyword], Map.get(dataset, :title))
  end

  defp handle_get_document_response({:ok, %{body: %{_id: id, found: false}}}), do: {:error, "Dataset with id #{id} not found!"}
  defp handle_get_document_response(response), do: handle_response_with_body(response)

  defp handle_response({:ok, %{body: %{error: error}}}), do: {:error, error}
  defp handle_response(response), do: response
end
