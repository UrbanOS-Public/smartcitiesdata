defmodule DiscoveryApi.ElasticSearchCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's search index layer.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate
  use Properties, otp_app: :discovery_api

  @url Application.get_env(:discovery_api, :elasticsearch)[:url]
  @indices Application.get_env(:discovery_api, :elasticsearch)[:indices]

  using do
    quote do
      import DiscoveryApi.ElasticSearchCase
    end
  end

  setup _tags do
    delete_indices()
    create_indices()

    on_exit(fn ->
      delete_indices()
    end)

    [
      es_url: @url,
      es_indices: @indices
    ]
  end

  # as much as it would be nice to have these use the real ones in the search index module, it might create havoc if that breaks
  defp create_indices() do
    Enum.map(@indices, fn {_id, index} ->
      create_es_index(index[:name], index[:options])
    end)
  end

  defp delete_indices() do
    Enum.map(@indices, fn {_id, index} ->
      delete_es_index(index[:name])
    end)
  end

  def create_es_index(name, options) do
    case Elastix.Index.exists?(@url, name) do
      {:ok, false} ->
        Elastix.Index.create(@url, name, options)

      _ ->
        :ok
    end
  end

  def delete_es_index(name) do
    case Elastix.Index.exists?(@url, name) do
      {:ok, true} ->
        Elastix.Index.delete(@url, name)

      _ ->
        :ok
    end
  end
end
