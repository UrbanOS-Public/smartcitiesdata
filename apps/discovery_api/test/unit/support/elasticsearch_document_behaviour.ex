defmodule ElasticsearchDocumentBehaviour do
  @moduledoc """
  Behaviour for the Elasticsearch.Document module to enable mocking
  """
  
  @callback update(any()) :: {:ok, any()} | {:error, any()}
  @callback delete(any()) :: {:ok, any()} | {:error, any()}
  @callback get(any()) :: {:ok, any()} | {:error, any()}
  @callback replace(any()) :: {:ok, any()} | {:error, any()}
  @callback replace_all(any()) :: {:ok, any()} | {:error, any()}
end