defmodule DiscoveryApi.Search.Elasticsearch.Shared do
  @moduledoc """
  Shared functionality across the suite of Elasticsearch modules.
  """
  use Properties, otp_app: :discovery_api

  getter(:elasticsearch, generic: true)

  def url() do
    Map.fetch!(configuration(), :url)
  end

  def dataset_index_name() do
    dataset_index()
    |> Map.fetch!(:name)
  end

  def dataset_index() do
    indices()
    |> Map.fetch!(:datasets)
  end

  defp indices() do
    Map.fetch!(configuration(), :indices)
  end

  defp configuration() do
    elasticsearch()
    |> Map.new()
  end

  def handle_response_with_body({:ok, %{body: %{error: error}}}), do: {:error, error}
  def handle_response_with_body({:ok, %{body: body}}), do: {:ok, body}
  def handle_response_with_body(response), do: response
end
