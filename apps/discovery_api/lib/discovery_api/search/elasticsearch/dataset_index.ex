defmodule DiscoveryApi.Search.Elasticsearch.DatasetIndex do
  @moduledoc """
  Manages an ElasticSearch index for datasets
  """
  require Logger
  import DiscoveryApi.Search.Elasticsearch.Shared

  def create() do
    %{name: name, options: options} = dataset_index()
    create(name, options)
  end

  def create_if_missing() do
    case Elastix.Index.exists?(url(), dataset_index_name()) do
      {:ok, true} ->
        Logger.warn("Dataset index already exists. Will not attempt to recreate.")
        {:ok, "Dataset Index not created."}

      {:ok, false} ->
        Logger.info("Creating new dataset index.")
        %{name: name, options: options} = dataset_index()
        create(name, options)
      {:error, error} ->
        Logger.error("An unexpected error occured. Dataset index not created.")
    end
  end

  def create(name, options \\ %{}) do
    elastic_create_index(name, options)
  end

  def delete() do
    delete(dataset_index_name())
  end

  def delete(name) do
    elastic_delete_index(name)
  end

  def get() do
    get(dataset_index_name())
  end

  def get(name) do
    elastic_get_index(name)
  end

  def reset() do
    reset(dataset_index())
  end

  def reset(name, options) do
    reset(%{name: name, options: options})
  end

  def reset(%{name: name, options: options}) do
    case delete(name) do
      {:ok, _} -> create(name, options)
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
