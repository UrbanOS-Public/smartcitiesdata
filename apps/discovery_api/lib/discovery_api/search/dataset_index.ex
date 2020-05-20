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
      {:ok, documents} ->
        {:ok, Enum.map(documents, &struct(Model, &1))}

      error ->
        error
    end
  end

  def search(term) do
    query = searchQuery(term)
    case elastic_search(query) do
      {:ok, documents} ->
        {:ok, Enum.map(documents, &struct(Model, &1))}

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
        {:ok, documents}

      error ->
        error
    end
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

  defp searchQuery(term) do
    %{
      "from" => 0,
      "query" => %{
        "bool" => %{
          "must" => [
              %{
                  "multi_match" => %{
                      "fields" => ["title", "description", "organizationDetails.orgTitle", "keywords"],
                      "fuzziness" => "AUTO",
                      "prefix_length" => 2,
                      "query" => term,
                      "type" => "most_fields"
                  }
              }
          ],
          "filter" => [
            %{ "term" =>  %{ "private" => false }}
          ]
        }
      },
      "size" => 10,
      "sort" => [%{"title" => %{"order" => "asc"}}]
    }
  end
end
