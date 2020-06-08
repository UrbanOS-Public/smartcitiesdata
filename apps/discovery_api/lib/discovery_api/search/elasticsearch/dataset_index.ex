defmodule DiscoveryApi.Search.Elasticsearch.DatasetIndex do
  @moduledoc """
  Manages an ElasticSearch index for datasets
  """
  import DiscoveryApi.Search.Elasticsearch.Shared

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

  def reset_index(%{name: name, options: options}) do
    case delete_index(name) do
      {:ok, _} -> create_index(name, options)
      error -> error
    end
  end

  def elastic_datasets_index_exists?() do
    Elastix.Index.exists?(url(), dataset_index_name())
    |> handle_index_exists_response()
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

  defp handle_index_exists_response({:ok, false}) do
    {:error, "Datasets index does not exist. Will not attempt to autocreate it."}
  end

  defp handle_index_exists_response({:ok, true}), do: true
  defp handle_index_exists_response(response), do: response

  defp handle_delete_index_response({:ok, %{body: %{error: %{type: "index_not_found_exception"}}}} = response), do: response
  defp handle_delete_index_response({:ok, %{body: %{error: error}}}), do: {:error, error}
  defp handle_delete_index_response(response), do: response
end
